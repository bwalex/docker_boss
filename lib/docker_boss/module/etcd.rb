require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'

require 'erb'
require 'ostruct'

require 'etcd'

class DockerBoss::Module::Etcd < DockerBoss::Module::Base
  class Config
    attr_accessor :host, :port

    def initialize(block)
      ConfigProxy.new(self).instance_eval(&block)
    end

    def setup_block
      @setup_block || Proc.new { }
    end

    def setup_block=(block)
      @setup_block = block
    end

    def change_block
      @change_block || Proc.new { |c| }
    end

    def change_block=(block)
      @change_block = block
    end

    class ConfigProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def host(h)
        self.host = h
      end

      def port(p)
        self.port = p
      end

      def setup(&b)
        self.setup_block = b
      end

      def change(&b)
        self.change_block = b
      end
    end
  end

  class SetupProcess
    include DockerBoss::Helpers::Mixin

    def initialize(client)
      @client = client
    end

    def absent(k, opts = {})
      opts = { recursive: false }.merge(opts)

      begin
        DockerBoss.logger.debug "etcd: (setup) Remove key `#{k}`"
        @client.delete(k, opts)
      rescue ::Etcd::KeyNotFound
      end
    end

    def dir(k)
      DockerBoss.logger.debug "etcd: (setup) Set key `#{k}` (dir)"
      @client.set(k, dir: true)
    end

    def set(k, v)
      DockerBoss.logger.debug "etcd: (setup) Set key `#{k}` => `#{v}`"
      @client.set(k, value: v)
    end
  end

  class ChangeProcess
    attr_accessor :values

    def initialize(change_block)
      @container = ChangeProxy.new(self)
      @block = change_block
    end

    def handle(containers)
      @values = {}
      containers.each { |c| @container.instance_exec c, &@block }
      @values
    end

    class ChangeProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def set(k, v)
        self.values[k] = v
      end
    end
  end

  def self.build(&block)
    DockerBoss::Module::Etcd.new(&block)
  end

  def initialize(&block)
    @config = Config.new(block)
    DockerBoss.logger.debug "etcd: Set up to connect to #{@config.host}, port #{@config.port}"
    @client = ::Etcd.client(host: @config.host, port: @config.port)
    @previous_keys = {}
    setup
  end

  def setup
    SetupProcess.new(@client).instance_eval(&@config.setup_block)
    @change_process = ChangeProcess.new(@config.change_block)
  end

  def trigger(containers, trigger_id)
    new_keys = @change_process.handle(containers)
    changes = DockerBoss::Helpers.hash_diff(@previous_keys, new_keys)
    @previous_keys = new_keys

    changes[:removed].each do |k,v|
      DockerBoss.logger.debug "etcd: Remove key `#{k}`"
      @client.delete(k)
    end

    changes[:added].each do |k,v|
      DockerBoss.logger.debug "etcd: Add key `#{k}` => `#{v}`"
      @client.set(k, value: v)
    end

    changes[:changed].each do |k,v|
      DockerBoss.logger.debug "etcd: Update key `#{k}` => `#{v}`"
      @client.set(k, value: v)
    end
  end

end
