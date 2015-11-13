require 'docker_boss'
require 'docker_boss/module/consul'
require 'json'

RSpec.describe DockerBoss::Module::Consul do
  describe "setup" do
    it "does nothing without a setup config" do
      DockerBoss::Module::Consul.build do
        host '127.0.0.1'
        port 8200
        protocol :http

        setup do
        end
      end
    end

    describe "kv" do
      it "can set a key with a plain value" do
        req = stub_request(:put, "http://127.0.0.1:8200/v1/kv/test/1/key").
          with(:body => "value").
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            set '/test/1/key', 'value'
          end
        end

        expect(req).to have_been_requested
      end

      it "can set a key with a hash" do
        hsh = {
          :a => 'A',
          :b => 'B'
        }

        req = stub_request(:put, "http://127.0.0.1:8200/v1/kv/test/1/key").
          with(:body => hsh.to_json).
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            set '/test/1/key', hsh
          end
        end

        expect(req).to have_been_requested
      end

      it "can create a directory" do
        req = stub_request(:put, "http://127.0.0.1:8200/v1/kv/test/1/key").
          with(:body => "null").
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            dir '/test/1/key'
          end
        end

        expect(req).to have_been_requested
      end

      it "can delete a key" do
        req = stub_request(:delete, "http://127.0.0.1:8200/v1/kv/test/1/key").
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent '/test/1/key'
          end
        end

        expect(req).to have_been_requested
      end

      it "can delete a key recursively" do
        req = stub_request(:delete, "http://127.0.0.1:8200/v1/kv/test/1/key").
          with(:query => { "recurse" => nil }).
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent '/test/1/key', recursive: true
          end
        end

        expect(req).to have_been_requested
      end

      it "can cope with a 404 on a delete" do
        req = stub_request(:delete, "http://127.0.0.1:8200/v1/kv/test/1/key").
          to_return(:status => 404, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent '/test/1/key'
          end
        end

        expect(req).to have_been_requested
      end

    end

    describe "services" do
      before(:each) do
        stub_request(:get, "http://127.0.0.1:8200/v1/agent/services").
          to_return(
            :status => 200,
            :body => {
              "abc" => {
                "ID"      => "abc",
                "Service" => "redis",
                "Tags"    => nil,
                "Address" => "127.0.0.1",
                "Port"    => 8000
              },
              "def" => {
                "ID"      => "def",
                "Service" => "redis",
                "Tags"    => ["tag1", "tag2"],
                "Address" => "127.0.0.1",
                "Port"    => 8000
              },
              "ghi" => {
                "ID"      => "ghi",
                "Service" => "redis",
                "Tags"    => ["tag3"],
                "Address" => "127.0.0.1",
                "Port"    => 8000
              },
              "xyz" => {
                "ID"      => "xyz",
                "Service" => "redis",
                "Tags"    => ["tag3", "tag5"],
                "Address" => "127.0.0.1",
                "Port"    => 8000
              }
            }.to_json,
            :headers => {})
      end

      it "can remove all services" do
        reqs = []

        reqs << stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/abc").
          to_return(:status => 200, :body => "", :headers => {})
        reqs << stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/def").
          to_return(:status => 200, :body => "", :headers => {})
        reqs << stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/ghi").
          to_return(:status => 200, :body => "", :headers => {})
        reqs << stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/xyz").
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent_services
          end
        end

        reqs.each { |req| expect(req).to have_been_requested }
      end

      it "can remove services with given tag(s)" do
        reqs = []
        reqs << stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/def").
          to_return(:status => 200, :body => "", :headers => {})
        reqs << stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/xyz").
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent_services :tag1, :tag5
          end
        end

        reqs.each { |req| expect(req).to have_been_requested }
      end

      it "can create a new service" do
        hsh = {
          :a => 'A',
          :b => 'B'
        }

        req = stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
          to_return(:status => 200, :body => "", :headers => {})

        expected_body = {
            "ID"      => "redis1",
            "Name"    => "redis",
            "Tags"    => %w{master v1},
            "Address" => "127.0.0.1",
            "Port"    => 8000,
            "Check"   => {
              "HTTP"  => "http://localhost:5000/health"
            }
        }

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            service 'redis1',
              name: 'redis',
              tags: %w{master v1},
              address: '127.0.0.1',
              port: 8000,
              check: {
                http: 'http://localhost:5000/health'
              }
          end
        end

        expect(
          a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            with { |req| JSON.parse(req.body) == expected_body }
        ).to have_been_made
      end
    end
  end

  describe 'change tracking' do
    before(:each) do
      @container1 =
        {
          "Config" => {
              "Env" => {
                "FOO"  => "mariadb.test",
                "PATH" => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              }
          },
          "Id" => "id1",
          "Image" => "dc7e7b74d729c8b7ffab9ac5bc4b9a1463739e085b461b29928bf2fee1ff8303",
          "Name" => "/mariadb",
          "NetworkSettings" => {
             "IPAddress" => "172.17.0.19",
          },
          "Volumes" => {
             "/var/lib/mysql" => "/var/lib/docker/vfs/dir/1e3963ffc558c14d4b29bea89d6eafca9945500f5c80ea94b94b6e8664d5a1dc"
          }
        }

      @container1_mod = Marshal.load(Marshal.dump(@container1))
      @container1_mod['NetworkSettings']['IPAddress'] = "172.17.100.100"

      @container2 =
        {
          "Config" => {
              "Env" => {
                 "FOO"  => "pgdb.test",
                 "PATH" => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              }
          },
          "Id" => "id2",
          "Image" => "aa1b1001ceca36a899559de64f115b0b20591d2465793ab728e3968e3036c7c4",
          "Name" => "/pgdb",
          "NetworkSettings" => {
             "IPAddress" => "172.17.1.23",
          },
          "Volumes" => {
          }
        }

      @container2_mod = Marshal.load(Marshal.dump(@container2))
      @container2_mod['Config']['Env']['FOO'] = "modified.test"

      @container3 =
        {
          "Config" => {
              "Env" => {
                 "FOO"  => "redis.test",
                 "PATH" => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              }
          },
          "Id" => "id3",
          "Image" => "06c788363068afcf7a9678095e418738cd49688787555d163e424e4b902174a8",
          "Name" => "/redis",
          "NetworkSettings" => {
             "IPAddress" => "172.17.5.99",
          },
          "Volumes" => {
          }
        }
    end

    context 'of services' do
      before(:each) do
        @inst = DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http
          default_tags :tag1, :tag2

          change do |c|
            service c['Id'], name: c['Name'][1..-1],
                             address: c['NetworkSettings']['IPAddress'],
                             tags: [:tag3]
          end
        end
      end

      context 'with tags' do
        it 'applies the default tags and any per-service tags' do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
              with(:body => hash_including({
              'ID' => @container1['Id'],
              'Name' => 'mariadb',
              'Address' => '172.17.0.19',
              'Tags' => %w{tag3 tag1 tag2}
            }))
          ).to have_been_made
        end
      end

      context 'with a clean slate' do
        it 'registers new services' do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1, @container2], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
              with(:body => hash_including({
              'ID' => @container1['Id'],
              'Name' => 'mariadb',
              'Address' => '172.17.0.19'
            }))
          ).to have_been_made


          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
              with(:body => hash_including({
              'ID' => @container2['Id'],
              'Name' => 'pgdb',
              'Address' => '172.17.1.23'
            }))
          ).to have_been_made
        end
      end


      context 'with existing services' do
        before(:each) do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1, @container2], nil)

          WebMock.reset!
        end

        it 'removes services when the corresponding container is removed' do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/id1").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container2], nil)

          expect(a_request(:put, 'http://127.0.0.1:8200/v1/agent/service/deregister/id1')).
              to have_been_made
        end

        it 'updates an existing service if needed' do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/id1").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1_mod, @container2], nil)

          expect(a_request(:put, 'http://127.0.0.1:8200/v1/agent/service/deregister/id1')).
              to have_been_made

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
              with(:body => hash_including({
              'ID' => 'id1',
              'Name' => 'mariadb',
              'Address' => '172.17.100.100'
            }))
          ).to have_been_made
        end

        it 'adds new services for new containers' do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1, @container3, @container2], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
              with(:body => hash_including({
              'ID' => 'id3',
              'Name' => 'redis',
              'Address' => '172.17.5.99'
            }))
          ).to have_been_made
        end

        it 'does nothing when nothing changes' do
          stub_request :any, /.*/

          @inst.trigger([@container2, @container1], nil)

          assert_not_requested :any, /.*/
        end

        it 'can both add and remove services in one go' do
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/deregister/id1").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container3, @container2], nil)

          expect(a_request(:put, 'http://127.0.0.1:8200/v1/agent/service/deregister/id1')).
              to have_been_made

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
              with(:body => hash_including({
              'ID' => 'id3',
              'Name' => 'redis',
              'Address' => '172.17.5.99'
            }))
          ).to have_been_made
        end
      end

      context 'with conflicts' do
        it 'only registers conflicting services once' do
          @inst = DockerBoss::Module::Consul.build do
            host '127.0.0.1'
            port 8200
            protocol :http

            change do |c|
              service 'conflicting_service', name: c['Name'][1..-1],
                               address: c['NetworkSettings']['IPAddress'],
                               tags: [:tag3]
            end
          end

          stub_request(:put, "http://127.0.0.1:8200/v1/agent/service/register").
            to_return(:status => 200, :body => "", :headers => {})

          expect(DockerBoss.logger).to receive(:warn).with(%r(conflicting_service)).once

          @inst.trigger([@container1, @container2], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/agent/service/register")
          ).to have_been_made.once
        end
      end
    end

    context 'of key-value pairs' do
      before(:each) do
        @inst = DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          change do |c|
            set "/foo/#{c['Id']}", foo: c['Config']['Env']['FOO']
            set "/bar/#{c['Id']}", 'test'
          end
        end
      end

      context 'with a clean slate' do
        it 'sets new key-value pairs' do
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id1").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/bar/id1").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id1").
              with(:body => {
              'foo' => 'mariadb.test',
            }.to_json)
          ).to have_been_made

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/bar/id1").
              with(:body => 'test')
          ).to have_been_made
        end
      end

      context 'with existing keys' do
        before(:each) do
          stub_request :any, /.*/

          @inst.trigger([@container1, @container2], nil)

          WebMock.reset!
        end

        it 'removes keys when the corresponding container is removed' do
          stub_request(:delete, "http://127.0.0.1:8200/v1/kv/foo/id1").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:delete, "http://127.0.0.1:8200/v1/kv/bar/id1").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container2], nil)

          expect(
            a_request(:delete, "http://127.0.0.1:8200/v1/kv/foo/id1")
          ).to have_been_made
          expect(
            a_request(:delete, "http://127.0.0.1:8200/v1/kv/bar/id1")
          ).to have_been_made
        end

        it 'updates an existing key if needed' do
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id2").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1, @container2_mod], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id2").
              with(:body => {
              'foo' => 'modified.test'
            }.to_json)
          ).to have_been_made
        end

        it 'adds new keys for new containers' do
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id3").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/bar/id3").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container1, @container3, @container2], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id3").
              with(:body => {
              'foo' => 'redis.test',
            }.to_json)
          ).to have_been_made

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/bar/id3").
              with(:body => 'test')
          ).to have_been_made
        end

        it 'does nothing when nothing changes' do
          stub_request :any, /.*/

          @inst.trigger([@container2, @container1], nil)

          assert_not_requested :any, /.*/
        end

        it 'can both add and remove keys in one go' do
          stub_request(:delete, "http://127.0.0.1:8200/v1/kv/foo/id1").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:delete, "http://127.0.0.1:8200/v1/kv/bar/id1").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id3").
            to_return(:status => 200, :body => "", :headers => {})
          stub_request(:put, "http://127.0.0.1:8200/v1/kv/bar/id3").
            to_return(:status => 200, :body => "", :headers => {})

          @inst.trigger([@container3, @container2], nil)

          expect(
            a_request(:delete, "http://127.0.0.1:8200/v1/kv/foo/id1")
          ).to have_been_made
          expect(
            a_request(:delete, "http://127.0.0.1:8200/v1/kv/bar/id1")
          ).to have_been_made

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/foo/id3").
              with(:body => {
              'foo' => 'redis.test',
            }.to_json)
          ).to have_been_made

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/bar/id3").
              with(:body => 'test')
          ).to have_been_made
        end
      end

      context 'with conflicts' do
        it 'only sets conflicting key once' do
          @inst = DockerBoss::Module::Consul.build do
            host '127.0.0.1'
            port 8200
            protocol :http

            change do |c|
              set '/foo/conflict', c['Id']
            end
          end

          stub_request(:put, "http://127.0.0.1:8200/v1/kv/foo/conflict").
            to_return(:status => 200, :body => "", :headers => {})

          expect(DockerBoss.logger).to receive(:warn).with(%r(/foo/conflict)).once

          @inst.trigger([@container1, @container2], nil)

          expect(
            a_request(:put, "http://127.0.0.1:8200/v1/kv/foo/conflict")
          ).to have_been_made.once
        end
      end
    end
  end
end
