require 'rubydns'
require 'resolv'
require 'docker_boss'
require 'docker_boss/module'
require 'thread'

class DockerBoss::Module::DNS < DockerBoss::Module
  attr_reader :records

  def initialize(config)
    @records = {}
    @config = config
    DockerBoss.logger.debug "dns: Set up"
  end

  def run
    listen = []
    @config['listen'].each do |l|
      listen << [:udp, l['host'], l['port'].to_i]
      listen << [:tcp, l['host'], l['port'].to_i]
    end

    DockerBoss.logger.debug "dns: Starting DNS server"

    Thread.new do
      RubyDNS::run_server(:listen => listen, :ttl => @config['ttl'], :upstream_dns => @config['upstream'], :supervisor_class => Server, :manager => self)
    end
  end

  def trigger(containers, trigger_id)
    records = {}
    containers.each do |c|
      names = DockerBoss::Helpers.render_erb(@config['spec'], :container => c)
      names.lines.each do |n|
        records[n.lstrip.chomp] = c['NetworkSettings']['IPAddress']
      end
    end

    @records = records
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

      @ttl = options[:ttl]
      servers = options[:upstream_dns].map { |ip| [:udp, ip, 53] }
      servers.concat(options[:upstream_dns].map { |ip| [:tcp, ip, 53] })
      @resolver = RubyDNS::Resolver.new(servers)
    end

    def process(name, resource_class, transaction)
      if records.has_key? name
        # XXX: revisit whenever docker supports IPv6, for AAAA records...
        if [IN::A].include? resource_class
          transaction.respond!(records[name], :ttl => @ttl)
        else
          transaction.fail!(:NXDomain)
        end
      else
        transaction.passthrough!(@resolver)
      end
    end
  end
end
