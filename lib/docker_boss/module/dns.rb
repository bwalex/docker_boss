require 'rubydns'
require 'resolv'
require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'
require 'thread'

class DockerBoss::Module::DNS < DockerBoss::Module::Base
  attr_reader :records

  class Config
    attr_accessor :ttl, :listens, :upstreams, :zones

    def initialize(block)
      @listens = []
      @upstreams = []
      @zones = []
      @ttl = 5
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

      def ttl(t)
        self.ttl = t
      end

      def listen(h, p)
        self.listens << {host: h, port: p}
      end

      def upstream(srv)
        self.upstreams << srv
      end

      def zone(z)
        self.zones << z
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
    attr_accessor :records

    def initialize(block)
      @records = {}
      SetupProxy.new(self).instance_eval(&block)
    end

    class SetupProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def set(r, k, v)
        (self.records[r] ||= {})[k] = v
      end
    end
  end

  class ChangeProcess
    attr_accessor :values, :names

    def initialize(change_block)
      @container = ChangeProxy.new(self)
      @block = change_block
    end

    def handle(containers, initial_records = {})
      @records = initial_records
      containers.each do |c|
        @names = []
        @container.instance_exec c, &@block
        names.each do |n|
          (@records[:A] ||= {})[n] = c['NetworkSettings']['IPAddress'] if c['NetworkSettings']['IPAddress'] != ''
          (@records[:AAAA] ||= {})[n] = c['NetworkSettings']['GlobalIPv6Address'] if c['NetworkSettings']['GlobalIPv6Address'] != ''
        end
      end
      @records
    end

    class ChangeProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def name(k)
        self.names << k
      end
    end
  end

  def self.build(&block)
    DockerBoss::Module::DNS.new(&block)
  end

  def initialize(&block)
    @records = {}
    @setup_records = {}
    @config = Config.new(block)
    DockerBoss.logger.debug "dns: Set up"
    setup
  end

  def setup_records
    @setup_records.each_with_object({}) { |(k,v),h| h[k] = v.clone }
  end

  def setup
    @setup_records = SetupProcess.new(@config.setup_block).records
    @change_process = ChangeProcess.new(@config.change_block)
  end

  def run
    listen = []

    DockerBoss.logger.debug "dns: Starting DNS server, really"

    @config.listens.each do |v|
      h = v[:host]
      p = v[:port]
      listen << [:udp, h, p]
      listen << [:tcp, h, p]
      DockerBoss.logger.debug "dns: Listening on #{h} (port: #{p})"
    end

    Thread.new do
      RubyDNS::run_server(:listen => listen, :ttl => @config.ttl, :upstream_dns => @config.upstreams, :zones => @config.zones, :server_class => Server, :supervisor_class => Server, :manager => self)
    end
  end

  def trigger(containers, _trigger_id)
    @records = @change_process.handle(containers, setup_records)
  end

  class Server < RubyDNS::Server
    attr_writer :records
    IN = Resolv::DNS::Resource::IN

    def records
      @manager.records
    end

    def initialize(options = {})
      super(options)
      @manager = options[:manager]

      puts "ho?"

      @ttl = options[:ttl].to_i
      @zones = options[:zones]
      servers = options[:upstream_dns].map { |ip| [:udp, ip, 53] }
      servers.concat(options[:upstream_dns].map { |ip| [:tcp, ip, 53] })
      @resolver = RubyDNS::Resolver.new(servers)
    end

    def process(name, resource_class, transaction)
      zone = @zones.find { |z| name =~ /#{z}$/ }
      puts "Records:"
      p records

      if [IN::AAAA].include? resource_class and
          records[:AAAA].has_key? name
          transaction.respond!(records[:AAAA][name], :ttl => @ttl)
      elsif [IN::A].include? resource_class and
          records[:A].has_key? name
          transaction.respond!(records[:A][name], :ttl => @ttl)
      elsif zone
        soa = Resolv::DNS::Resource::IN::SOA.new(Resolv::DNS::Name.create("#{zone}"), Resolv::DNS::Name.create("dockerboss."), 1, @ttl, @ttl, @ttl, @ttl)
        transaction.add([soa], :name => "#{zone}.", :ttl => @ttl, :section => :authority)
        transaction.fail!(:NXDomain)
      else
        transaction.passthrough!(@resolver)
      end
    end
  end
end
