require 'docker_boss'
require 'docker_boss/module'
require 'docker_boss/helpers'
require 'thread'
require 'celluloid'
require 'timers'
require 'net/http'
require 'uri'
require 'cgi'

class DockerBoss::Module::InfluxDB < DockerBoss::Module
  class Error < StandardError; end

  class Config
    attr_accessor :protocol, :host, :port, :user, :pass, :no_verify, :database
    attr_accessor :use_ints
    attr_accessor :interval, :allow, :cgroup_path, :cgroup_docker
    attr_accessor :prefix, :tags

    def initialize(block)
      @protocol = :http
      @host = 'localhost'
      @port = 8086
      @database = 'containers'
      @prefix = (c) -> "container.#{c[:name]}."
      @interval = 60
      @cgroup_path = '/sys/fs/cgroup'
      @use_ints = false

      ConfigProxy.new(self).instance_eval(&block)
    end

    def url
      "#{protocol}://#{host}:#{port}"
    end

    class ConfigProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def protocol(p)
        raise ArgumentError, "Unknown InfluxDB protocol #{p}" unless ['http', 'https'].include? p.to_s
        self.protocol = p.to_s
      end

      def host(h)
        self.host = h
      end

      def port(p)
        self.port = p
      end

      def user(u)
        self.user = u
      end

      def pass(p)
        self.pass = p
      end

      def no_verify(v)
        self.no_verify = v
      end

      def use_ints(v)
        self.use_ints = v
      end

      def database(d)
        self.database = d
      end

      def prefix(p = '', &block)
        self.prefix = block_given? ? block : p
      end

      def tags(t = [], &block)
        self.tags = block_given? ? block : t
      end

      def interval(i)
        self.interval = i
      end

      def cgroup_path(p)
        self.cgroup_path = p
        self.cgroup_docker = File.exists? "#{p}/blkio/docker"
      end
    end
  end

  def self.build(&block)
    DockerBoss::Module::InfluxDB.new(&block)
  end

  def initialize(&block)
    @config = Config.new(block)
    @mutex = Mutex.new
    @containers = []

    @pool = Worker.pool(args: [@config])
    @timers = Timers::Group.new

    DockerBoss.logger.debug "influxdb: Set up to connect to #{@config.url}"
  end

  def connection
    @http ||=
      begin
        http = Net::HTTP.new(@config.host, @config.port)
        http.use_ssl = @config.protocol == 'https'
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @config.no_verify
        http
      end
  end

  def do_query(q)
    request = Net::HTTP::Get.new("/query?db=#{CGI.escape(@config.database)}&q=#{CGI.escape(q)}")
    request.basic_auth @config.user, @config.pass
    connection.request(request)
  end

  def test_connection!
    response = do_query('list series')
    raise Error.new response.body unless response.kind_of? Net::HTTPSuccess
    DockerBoss.logger.debug "influxdb: Connection tested successfully"
  end

  def do_post!(data)
    request = Net::HTTP::Post.new("/write?db=#{CGI.escape(@config.database)}")
    request.basic_auth @config.user, @config.pass
    request.add_field('Content-Type', 'text/plain')
    request.body = line_protocol(data)
    response = connection.request(request)
    raise Error.new response.body unless response.kind_of? Net::HTTPSuccess
  end

  def line_escape(v)
    v.gsub(/,/, '\,').gsub(/\s/, '\ ').gsub(/\\/, '\\')
  end

  def line_str_escape(v)
    v.gsub(/"/, '\"')
  end

  def line_value(v)
    if v.is_a? Integer
      @config.use_ints ? "#{v}i" : "#{v}"
    elsif v.is_a? Float
      "#{v}"
    elsif v.is_a? String or v.is_a? Symbol
      %{"#{line_str_escape(v)}"}
    else
      v ? "true" : "false"
    end
  end

  def line_protocol(data)
    lines =
      data.map do |d|
        m_t = [ line_escape(d[:measurement]) ] + d[:tags].map { |k,v| "#{line_escape(k)}=#{line_escape(v)}" }

        "#{m_t.join(',')} value=#{line_value(d[:value])} #{d[:timestamp]}"
      end

    lines.join("\n")
  end

  def run
    @timers.every(@config.interval) { sample }

    Thread.new do
      loop { @timers.wait }
    end
  end

  def trigger(containers, trigger_id)
    @mutex.synchronize {
      @containers = containers
    }
  end

  def sample
    containers = []

    @mutex.synchronize do
      containers = @containers.map do |c|
        info = {
          id: c['Id'],
          name: c['Name'][1..-1],
        }

        tags =
          if @config.tags.respond_to? :call
            @config.tags.call(info)
          else
            @config.tags
          end

        prefix =
          if @config.prefix.respond_to? :call
            @config.prefix.call(info)
          else
            @config.prefix
          end

        info.merge(tags: tags, prefix: prefix)
      end
    end

    futures = containers.map { |c| @pool.future :sample_container, c }

    data = futures.map { |f| f.value }

    begin
      do_post! data
    rescue DockerBoss::Module::InfluxDB::Error => e
      DockerBoss.logger.error "influxdb: Error posting update: #{e.message}"
    rescue Net::OpenTimeout => e
      DockerBoss.logger.error "influxdb: Error posting update: #{e.message}"
    rescue Errno::ECONNREFUSED => e
      DockerBoss.logger.error "influxdb: Error posting update: #{e.message}"
    rescue SocketError => e
      DockerBoss.logger.error "influxdb: Error posting update: #{e.message}"
    end
  end

  class Worker
    include Celluloid

    def initialize(config)
      @config = config
    end

    def build_path(id, type, file)
      if @config.cgroup_docker
        "#{@config.cgroup_path}/#{type}/docker/#{id}/#{file}"
      else
        "#{@config.cgroup_path}/#{type}/system.slice/docker-#{id}.scope/#{file}"
      end
    end

    def sample_container(container)
      time_now = Time.now.to_i

      kv_sample(container[:id], 'memory', 'memory.stat', 'memory') { |k,v| data[k] = v }
      kv_sample(container[:id], 'cpuacct', 'cpuacct.stat', 'cpuacct') { |k,v| data[k] = v }
      ['blkio.io_serviced', 'blkio.io_service_bytes',
       'blkio.io_wait_time', 'blkio.io_service_time', 'blkio.io_queued'].each do |f|
        blkio_sample(container[:id], 'blkio', f, f.gsub(/\./, '.')) { |k,v| data[k] = v }
      end
      ['blkio.sectors'].each do |f|
        blkio_v_sample(container[:id], 'blkio', f, f.gsub(/\./, '.')) { |k,v| data[k] = v }
      end

      data.map do |k,v|
        {
          measurement: "#{container[:prefix]}#{k}",
          tags:        container[:tags],
          value:       v,
          timestamp:   "#{time_now}000000000"
        }
      end
    end

    def kv_sample(id, type, file, key_prefix)
      return to_enum(:kv_sample, id, type, file, key_prefix) unless block_given?

      File.readlines(build_path(id, type, file)).each do |line|
        (k,v) = line.chomp.split(/\s+/, 2)
        yield "#{key_prefix}.#{k.downcase}", v.to_i
      end
    end

    def blkio_sample(id, type, file, key_prefix)
      return to_enum(:blkio_sample, id, type, file, key_prefix) unless block_given?
      data = {}

      File.readlines(build_path(id, type, file)).each do |line|
        (maj_min,k,v) = line.chomp.split(/\s+/, 3)
        if maj_min != 'Total'
          data["#{key_prefix}.#{k.downcase}"] ||= 0
          data["#{key_prefix}.#{k.downcase}"] += v.to_i
        end
      end

      data.each { |k,v| yield k, v }
    end

    def blkio_v_sample(id, type, file, key)
      return to_enum(:blkio_v_sample, id, type, file, key) unless block_given?
      data = {}

      File.readlines(build_path(id, type, file)).each do |line|
        (maj_min,v) = line.chomp.split(/\s+/, 2)
        data[key] ||= 0
        data[key] += v.to_i
      end

      data.each { |k,v| yield k, v }
    end
  end
end
