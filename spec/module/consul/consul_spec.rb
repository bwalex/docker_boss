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
          with(:body => "\"value\"").
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
  end
end
