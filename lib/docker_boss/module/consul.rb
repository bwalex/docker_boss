# GET /v1/agent/services
#
# {
#   "redis": {
#     "ID": "redis",
#     "Service": "redis",
#     "Tags": null,
#     "Address": "",
#     "Port": 8000
#   }
# }
#
# PUT /v1/agent/service/register
#
# {
#   "ID": "redis1",
#   "Name": "redis",
#   "Tags": [
#     "master",
#     "v1"
#   ],
#   "Address": "127.0.0.1",
#   "Port": 8000,
#   "Check": {
#     "Script": "/usr/local/bin/check_redis.py",
#     "HTTP": "http://localhost:5000/health",
#     "Interval": "10s",
#     "TTL": "15s"
#   }
# }
#
# PUT/GET? /v1/agent/service/deregister/<serviceId>
#
# GET/PUT/DELETE /v1/kv/<key>
# GET - ?raw - otherwise, base64
# DELETE - ?recurse
#
# use tags to identify services registered via docker_boss
# allow removing only services matching some tag

require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'
require 'base64'
require 'net/http'
require 'uri'
require 'cgi'

class DockerBoss::Module::Consul < DockerBoss::Module::Base
  class Client
    def initialize(host, port, protocol = :http, no_verify = false)
      @host = host
      @port = port
      @protocol = protocol
      @no_verify = no_verify
    end

    def connection
      @http ||=
        begin
          http = Net::HTTP.new(@host, @port)
          http.use_ssl = @protocol == :https
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @no_verify
          http
        end
    end

    def services
      return enum_for(:services) unless block_given?

      request = Net::HTTP::Get.new("/v1/agent/services")
      response = connection.request(request)
      fail Error unless response.kind_of? Net::HTTPSuccess
      JSON.parse(response.body).each do |_,v|
        yield v
      end
    end

    def service_create(s)
      request = Net::HTTP::Put.new("/v1/agent/service/register")
      request.body = s.to_json
      response = connection.request(request)
      fail Error unless response.kind_of? Net::HTTPSuccess
    end

    def service_delete(id)
      request = Net::HTTP::Put.new("/v1/agent/service/deregister/#{id}")
      response = connection.request(request)
      fail Error unless response.kind_of? Net::HTTPSuccess
    end

    def delete(k, recursive = false)
      path = "/v1/kv/#{k}"
      path += "?recurse" if recursive
      request = Net::HTTP::Put.new(path)
      response = connection.request(request)
      fail Error unless response.kind_of? Net::HTTPSuccess
    end

    def set(k, v)
      request = Net::HTTP::Put.new("/v1/kv/#{k}")
      request.body = v
      response = connection.request(request)
      fail Error unless response.kind_of? Net::HTTPSuccess
    end

    def get(k)
      request = Net::HTTP::Get.new("/v1/kv/#{k}")
      response = connection.request(request)
      fail Error unless response.kind_of? Net::HTTPSuccess
      data = JSON.parse(response.body)
      Base64.decode(data['Value'])
    end
  end


  class Config
    attr_accessor :host, :port, :protocol, :no_verify, :default_tags

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
        @client.delete(k, opts)
      rescue ::Net::HTTPNotFound
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
      DockerBoss.logger.debug "consul: (setup) Add service `#{k}`"
      @client.service_create(k, ::DockerBoss::Module::Consul.xlate_service(v, @config))
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
      @values,@services
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
    @client = Client.new(host: @config.host, port: @config.port)
    @previous_keys = {}
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
      @client.service_create(k, xlate_service(v, @config))
    end

    service_changes[:changed].each do |k,v|
      DockerBoss.logger.debug "consul: Update service `#{k}`"
      @client.service_delete(k)
      @client.service_create(k, xlate_service(v))
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
        v = xlate_service(v) if v.is_a? Hash
        [k,v]
      end
    ]
  end

  def self.xlate_service(s, @config)
    specials = {
      :id => 'ID',
      :http => 'HTTP',
      :ttl => 'TTL'
    }

    s = rename_keys(s, specials)

    s['Tags'] = (s['Tags'] || []) + @config.default_tags
    s
  end
end
