require 'docker_boss'
require 'docker_boss/module/dns'
require 'json'

RSpec.describe DockerBoss::Module::DNS do
  before(:each) do
    #Celluloid.logger = Logger.new
    Celluloid.boot
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

      expect('simple.test.docker').to have_dns.with_type('A').and_ttl(7).and_address('10.0.0.1').config(nameserver: '127.0.0.1', port: 65300)
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

      expect('simple.test.docker').to have_dns.with_type('A').and_ttl(7).and_address('10.0.0.1').config(nameserver: '127.0.0.1', port: 65300)
      expect('simple.test.docker').to have_dns.with_type('AAAA').and_ttl(7).and_address('1f::1:1').config(nameserver: '127.0.0.1', port: 65300)
    end
  end
end
