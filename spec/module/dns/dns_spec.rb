require 'docker_boss'
require 'docker_boss/module/dns'
require 'json'
require 'resolv'
require 'dnsruby'

RSpec.describe DockerBoss::Module::DNS do
  before(:each) do
    Celluloid.logger = Logger.new(STDOUT)
    Celluloid.logger.level = Logger::ERROR
    Celluloid.boot

    @resolver = Dnsruby::Resolver.new(nameserver: '127.0.0.1', port: 65300)
    @resolver.query_timeout = 2
    @resolver.do_caching = false
  end

  after(:each) do
    Celluloid.shutdown
  end

  describe "setup" do
    it "can set up A records" do
      inst = DockerBoss::Module::DNS.build do
        listen '127.0.0.1', 65300
        ttl 7

        setup do
          set :A, 'simple.test.docker', '10.0.0.1'
        end
      end

      inst.run
      sleep 0.5

      res = @resolver.query('simple.test.docker', Dnsruby::Types.A).answer
      expect(res).to have_dns_record(%w{simple.test.docker. 7 IN A 10.0.0.1})
    end

    it "can set up AAAA records" do
      inst = DockerBoss::Module::DNS.build do
        listen '127.0.0.1', 65300
        ttl 7

        setup do
          set :A, 'simple.test.docker', '10.0.0.1'
          set :AAAA, 'simple.test.docker', '1f::1:1'
        end
      end

      inst.run
      sleep 0.5

      res = @resolver.query('simple.test.docker', Dnsruby::Types.AAAA).answer
      expect(res).to have_dns_record(%w{simple.test.docker. 7 IN AAAA 1f::1:1})
      expect(res).not_to have_dns_record(%w{simple.test.docker. 7 IN A 10.0.0.1})
    end

    it "can set up SRV records" do
      inst = DockerBoss::Module::DNS.build do
        listen '127.0.0.1', 65300
        ttl 5

        setup do
          set :SRV, 'http.srv.simple.test.docker', target: 'simple.test.docker', port: 80
          set :A, 'simple.test.docker', '10.0.0.1'
          set :AAAA, 'simple.test.docker', '1f::1:1'

          set :SRV, 'https.srv.simple.test.docker', target: 'foobar.test.docker', port: 443, weight: 10, priority: 15
        end
      end

      inst.run
      sleep 0.5

      res = @resolver.query('http.srv.simple.test.docker', Dnsruby::Types.SRV).answer
      expect(res).to have_dns_record(%w{http.srv.simple.test.docker. 5 IN SRV 0 0 80 simple.test.docker.})
      expect(res).to have_dns_record(%w{simple.test.docker. 5 IN A 10.0.0.1})
      expect(res).to have_dns_record(%w{simple.test.docker. 5 IN AAAA 1f::1:1})

      res = @resolver.query('https.srv.simple.test.docker', Dnsruby::Types.SRV).answer
      expect(res).to have_dns_record(%w{https.srv.simple.test.docker. 5 IN SRV 15 10 443 foobar.test.docker.})
      expect(res).not_to have_dns_record(%w{foobar.test.docker.})
    end

    it "can set up TXT records" do
      inst = DockerBoss::Module::DNS.build do
        listen '127.0.0.1', 65300
        ttl 7

        setup do
          set :TXT, '_dummy.test.docker', 'v=spf1 include:foo ~all'
          set :TXT, '_domainkey.simple.test.docker', 'k=rsa; p=FOOBAR'
          set :TXT, '_multiple.test.docker', 'foo=multiple', 'bar=strings'
        end
      end

      inst.run
      sleep 0.5

      res = @resolver.query('_domainkey.simple.test.docker', Dnsruby::Types.TXT).answer
      expect(res).to have_dns_record(%w{_domainkey.simple.test.docker. 7 IN TXT "k=rsa; p=FOOBAR"})

      res = @resolver.query('_dummy.test.docker', Dnsruby::Types.TXT).answer
      expect(res).to have_dns_record(%w{_dummy.test.docker. 7 IN TXT "v=spf1 include:foo ~all"})

      res = @resolver.query('_multiple.test.docker', Dnsruby::Types.TXT).answer
      expect(res).to have_dns_record(%w{_multiple.test.docker. 7 IN TXT "foo=multiple" "bar=strings"})
    end

    context 'with matching zone' do
      it "returns NXDomain authoritatively on a miss" do
        inst = DockerBoss::Module::DNS.build do
          listen '127.0.0.1', 65300
          zone '.docker'
          ttl 7

          setup do
            set :A, 'simple.test.docker', '10.0.0.1'
            set :AAAA, 'simple.test.docker', '1f::1:1'
          end
        end

        inst.run
        sleep 0.5

        expect { @resolver.query('foobar.test.docker', Dnsruby::Types.A).answer }.to raise_error(Dnsruby::NXDomain)
      end
    end
  end
end
