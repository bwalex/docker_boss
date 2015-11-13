require 'docker_boss'
require 'docker_boss/module/etcd'
require 'json'
require 'etcd'

RSpec.describe DockerBoss::Module::Etcd do
  before(:each) do
    @client = double("etcd client")
    allow(::Etcd).to receive(:client).and_return(@client)
  end

  describe "setup" do
    it "can be initialized without any setup or change blocks" do
      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001
      end
    end

    it "can set a key with a plain value" do
      expect(@client).to receive(:set).with('/test/1/key', value: 'value')

      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

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

      expect(@client).to receive(:set).with('/test/1/key', value: hsh.to_json)

      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

        setup do
          set '/test/1/key', hsh
        end
      end
    end

    it "can create a directory" do
      expect(@client).to receive(:set).with('/test/1/key', dir: true)

      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

        setup do
          dir '/test/1/key'
        end
      end
    end

    it "can delete a key" do
      expect(@client).to receive(:delete).with('/test/1/key', recursive: false)

      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

        setup do
          absent '/test/1/key'
        end
      end
    end

    it "can delete a key recursively" do
      expect(@client).to receive(:delete).with('/test/1/key', recursive: true)

      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

        setup do
          absent '/test/1/key', recursive: true
        end
      end
    end

    it "can cope with a KeyNotFound on a delete" do
      expect(@client).to receive(:delete).with('/test/1/key', recursive: false).and_raise(::Etcd::KeyNotFound)

      DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

        setup do
          absent '/test/1/key'
        end
      end
    end
  end

  describe 'key-value change tracking' do
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

    before(:each) do
      @inst = DockerBoss::Module::Etcd.build do
        host '127.0.0.1'
        port 4001

        change do |c|
          set "/foo/#{c['Id']}", foo: c['Config']['Env']['FOO']
          set "/bar/#{c['Id']}", 'test'
        end
      end
    end

    context 'with a clean slate' do
      it 'sets new key-value pairs' do
        expect(@client).to receive(:set).with('/foo/id1', value: { 'foo' => 'mariadb.test' }.to_json)
        expect(@client).to receive(:set).with('/bar/id1', value: 'test')

        @inst.trigger([@container1], nil)
      end
    end

    context 'with existing keys' do
      before(:each) do
        allow(@client).to receive(:set)

        @inst.trigger([@container1, @container2], nil)

        @client = double("etcd client 2")
        @inst.client = @client
      end

      it 'removes keys when the corresponding container is removed' do
        expect(@client).to receive(:delete).with('/foo/id1')
        expect(@client).to receive(:delete).with('/bar/id1')

        @inst.trigger([@container2], nil)
      end

      it 'updates an existing key if needed' do
        expect(@client).to receive(:set).with('/foo/id2', value: { 'foo' => 'modified.test' }.to_json)

        @inst.trigger([@container1, @container2_mod], nil)
      end

      it 'adds new keys for new containers' do
        expect(@client).to receive(:set).with('/foo/id3', value: { 'foo' => 'redis.test' }.to_json)
        expect(@client).to receive(:set).with('/bar/id3', value: 'test')

        @inst.trigger([@container1, @container3, @container2], nil)
      end

      it 'does nothing when nothing changes' do
        allow(@client).to receive(:set)
        allow(@client).to receive(:delete)

        @inst.trigger([@container2, @container1], nil)

        expect(@client).to_not have_received(:set)
        expect(@client).to_not have_received(:delete)
      end

      it 'can both add and remove keys in one go' do
        expect(@client).to receive(:delete).with('/foo/id1')
        expect(@client).to receive(:delete).with('/bar/id1')

        expect(@client).to receive(:set).with('/foo/id3', value: { 'foo' => 'redis.test' }.to_json)
        expect(@client).to receive(:set).with('/bar/id3', value: 'test')


        @inst.trigger([@container3, @container2], nil)
      end
    end

    context 'with conflicts' do
      it 'only sets conflicting key once' do
        @inst = DockerBoss::Module::Etcd.build do
          host '127.0.0.1'
          port 4001

          change do |c|
            set '/foo/conflict', c['Id']
          end
        end

        expect(@client).to receive(:set).once
        expect(DockerBoss.logger).to receive(:warn).with(%r(/foo/conflict)).once

        @inst.trigger([@container1, @container2], nil)
      end
    end
  end
end
