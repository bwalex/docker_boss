require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'

require 'erb'
require 'ostruct'

require 'etcd'

class DockerBoss::Module::Etcd < DockerBoss::Module
  def initialize(config)
    @config = config
    DockerBoss.logger.debug "etcd: Set up to connect to #{@config['server']['host']}, port #{@config['server']['port']}"
    @client = ::Etcd.client(host: @config['server']['host'], port: @config['server']['port'])
    @previous_keys = {}
  end

  def trigger(containers, trigger_id)
    @new_keys = process_specs(containers)
    changes = DockerBoss::Helpers.hash_diff(@previous_keys, @new_keys)
    @previous_keys = @new_keys

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

  def process_specs(containers)
    values = {}
    @config['sets'].each do |name,template|
      tmpl = ERB.new(template)
      containers.each do |container|
        ns = OpenStruct.new({ container: container })
        entries = tmpl.result(ns.instance_eval { binding })
        entries.lines.each do |line|
          (keyword, key, value) = line.lstrip.chomp.split(" ", 3)
          values[key] = value.to_s if keyword == 'ensure'
        end
      end
    end
    values
  end
end
