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
        stub_request(:put, "http://127.0.0.1:8200/v1/kv/test/1/key").
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
      end

      it "can set a key with a hash" do
        hsh = {
          :a => 'A',
          :b => 'B'
        }

        stub_request(:put, "http://127.0.0.1:8200/v1/kv/test/1/key").
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
      end

      it "can delete a key" do
        stub_request(:delete, "http://127.0.0.1:8200/v1/kv/test/1/key").
          to_return(:status => 200, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent '/test/1/key'
          end
        end
      end

      it "can delete a key recursively" do
        stub_request(:delete, "http://127.0.0.1:8200/v1/kv/test/1/key").
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
      end

      it "can cope with a 404 on a delete" do
        stub_request(:delete, "http://127.0.0.1:8200/v1/kv/test/1/key").
          to_return(:status => 404, :body => "", :headers => {})

        DockerBoss::Module::Consul.build do
          host '127.0.0.1'
          port 8200
          protocol :http

          setup do
            absent '/test/1/key'
          end
        end
      end
    end
  end
end
