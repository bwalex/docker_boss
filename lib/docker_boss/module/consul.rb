require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'
require 'base64'
require 'net/http'
require 'uri'
require 'cgi'
require 'delegate'

class DockerBoss::Module::Consul < DockerBoss::Module::Base
  class Client
    class Error < StandardError; end

    def initialize(host, port, protocol = :http, no_verify = false)
      @host = host
      @port = port
      @protocol = protocol
      @no_verify = no_verify
    end

    def connection
      @http ||=
        DockerBoss::Helpers::MiniHTTP.new(
          @host,
          port:      @port,
          protocol:  @protocol,
          no_verify: @no_verify
        )
    end

    def services
      return enum_for(:services) unless block_given?

      response = connection.request(Net::HTTP::Get, '/v1/agent/services')
      JSON.parse(response.body).each { |_,v| yield v }
    end

    def service_create(s)
      connection.request(
        Net::HTTP::Put, '/v1/agent/service/register',
        headers: { 'Content-Type' => 'application/json' },
        body: s.to_json
      )
    end

    def service_delete(id)
      connection.request(Net::HTTP::Put, "/v1/agent/service/deregister/#{id}")
    end

    def delete(k, recursive = false)
      response =
        if recursive
          connection.request(Net::HTTP::Delete, "/v1/kv#{k}", params: { recurse: nil })
        else
          connection.request(Net::HTTP::Delete, "/v1/kv#{k}")
      end
    end

    def set(k, v)
      connection.request(Net::HTTP::Put, "/v1/kv#{k}", body: v)
    end

    def get(k)
      response = connection.request(Net::HTTP::Get, "/v1/kv#{k}")
      data = JSON.parse(response.body)
      Base64.decode(data['Value'])
    end
  end


  class Config
    attr_accessor :host, :port, :protocol, :no_verify, :default_tags

    def initialize(block)
      @default_tags = []
      ConfigProxy.new(self).instance_eval(&block)
    end

    def setup_block
      @setup_block || Proc.new { }
    end

    def setup_block=(block)
      @setup_block = block
    end

    def change_block
      @change_block || Proc.new { |_| }
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

      def protocol(p)
        self.protocol = p
      end

      def no_verify(v)
        self.no_verify = v
      end

      def default_tags(*t)
        self.default_tags = t
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

    def initialize(client, config)
      @client = client
      @config = config
    end

    def absent(k, opts = {})
      opts = { recursive: false }.merge(opts)

      begin
        DockerBoss.logger.debug "consul: (setup) Remove key `#{k}`"
        @client.delete(k, opts[:recursive])
      rescue DockerBoss::Helpers::MiniHTTP::NotFoundError
      end
    end

    def dir(k)
      DockerBoss.logger.debug "consul: (setup) Set key `#{k}` (dir)"
      @client.set(k, nil.to_json)
    end

    def set(k, v)
      DockerBoss.logger.debug "consul: (setup) Set key `#{k}` => `#{v}`"
      @client.set(k, v.to_json)
    end

    def service(id, desc)
      DockerBoss.logger.debug "consul: (setup) Add service `#{id}`"
      @client.service_create(::DockerBoss::Module::Consul.xlate_service(desc.merge(id: id), @config))
    end

    def absent_services(*tags)
      tags = tags.map(&:to_s).to_set
      @client.services.each do |service|
        service_tags = ((service.has_key? 'Tags') ? service['Tags'] || [] : []).to_set
        if tags.empty? or not (tags & service_tags).empty?
          DockerBoss.logger.debug "consul: (setup) Remove service `#{service['ID']}`"
          @client.service_delete(service['ID'])
        end
      end
    end
  end

  class ChangeProcess
    attr_accessor :values
    attr_accessor :services

    def initialize(change_block)
      @container = ChangeProxy.new(self)
      @block = change_block
    end

    def handle(containers)
      @values = {}
      @services = {}
      containers.each { |c| @container.instance_exec c, &@block }
      [@values,@services]
    end

    class ChangeProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def set(k, v)
        self.values[k] = v
      end

      def service(id, desc)
        self.services[id] = desc
      end
    end
  end

  def self.build(&block)
    DockerBoss::Module::Consul.new(&block)
  end

  def initialize(&block)
    @config = Config.new(block)
    DockerBoss.logger.debug "consul: Set up to connect to #{@config.host}, port #{@config.port}"
    @client = Client.new(@config.host, @config.port, @config.protocol, @config.no_verify)
    @previous_keys = {}
    @previous_services = {}
    setup
  end

  def setup
    SetupProcess.new(@client, @config).instance_eval(&@config.setup_block)
    @change_process = ChangeProcess.new(@config.change_block)
  end

  def trigger(containers, _trigger_id)
    new_keys,new_services = @change_process.handle(containers)
    changes = DockerBoss::Helpers.hash_diff(@previous_keys, new_keys)
    service_changes = DockerBoss::Helpers.hash_diff(@previous_services, new_services)
    @previous_keys = new_keys
    @previous_services = new_services

    changes[:removed].each do |k,_|
      DockerBoss.logger.debug "consul: Remove key `#{k}`"
      @client.delete(k)
    end

    changes[:added].each do |k,v|
      DockerBoss.logger.debug "consul: Add key `#{k}` => `#{v}`"
      @client.set(k, v.to_json)
    end

    changes[:changed].each do |k,v|
      DockerBoss.logger.debug "consul: Update key `#{k}` => `#{v}`"
      @client.set(k, v.to_json)
    end

    service_changes[:removed].each do |k,_|
      DockerBoss.logger.debug "consul: Remove service `#{k}`"
      @client.service_delete(k)
    end

    service_changes[:added].each do |k,v|
      DockerBoss.logger.debug "consul: Add service `#{k}`"
      @client.service_create(::DockerBoss::Module::Consul.xlate_service(v.merge(id: k), @config))
    end

    service_changes[:changed].each do |k,v|
      DockerBoss.logger.debug "consul: Update service `#{k}`"
      @client.service_delete(k)
      @client.service_create(::DockerBoss::Module::Consul.xlate_service(v.merge(id: k), @config))
    end
  end

  def self.rename_keys(s, specials = {})
    Hash[
      s.map do |k,v|
        k =
          if specials.has_key? k
            specials[k]
          else
            k.to_s.capitalize
          end
        v = rename_keys(v, specials) if v.is_a? Hash
        [k,v]
      end
    ]
  end

  def self.xlate_service(s, config)
    specials = {
      :id => 'ID',
      :http => 'HTTP',
      :ttl => 'TTL'
    }

    s = rename_keys(s, specials)

    s['Tags'] = (s['Tags'] || []) + config.default_tags
    s
  end
end
