require 'docker_boss/version'
require 'docker_boss/engine'
require 'docker_boss'
require 'thor'
require 'docker'
require 'logger'
require 'syslog/logger'
require 'daemons'
require 'yaml'

class DockerBoss::CLI < Thor
  desc "once", "Run once and exit"
  method_option :config, :aliases => "-c", :type => :string, :required => true
  method_option :log,    :aliases => "-l", :type => :string, :default => "-"
  def once
    setup_logging
    read_config
    begin
      engine.refresh_and_trigger
    rescue Docker::Error::DockerError => e
      DockerBoss.logger.fatal "Error communicating with Docker: #{e.message}"
      exit 1
    end
  end

  desc "watch", "Run once, then watch for events"
  method_option :config,        :aliases => "-c", :type => :string,  :required => true
  method_option :log,           :aliases => "-l", :type => :string,  :default => "-"
  method_option :daemonize,     :aliases => "-D", :type => :boolean, :default => false
  method_option :incr_refresh,                    :type => :boolean, :default => false
  def watch
    setup_logging
    read_config

    thw = engine.event_loop

    Daemons.daemonize if options[:daemonize]

    begin
      engine.refresh_and_trigger
      thw.next_wait.join
    rescue Docker::Error::DockerError => e
      DockerBoss.logger.fatal "Error communicating with Docker: #{e.message}"
      exit 1
    rescue Exception => e
      DockerBoss.logger.fatal "Fatal unhandled exception in event loop: #{e.class.name} -> #{e.message}"
      e.backtrace.each { |line| DockerBoss.logger.fatal "    #{line}" }
      exit 1
    end
  end

  no_tasks do
    def engine
      @engine ||= begin
        engine = DockerBoss::Engine.new(options, @config)
        engine
      end
    end

    def setup_logging
      case options[:log]
      when "syslog"
        @logger = Syslog::Logger.new('docker-boss')
      when "-"
        @logger = Logger.new(STDOUT)
      else
        @logger = Logger.new(options[:log])
      end

      DockerBoss.logger=(@logger)
    end

    def read_config
      begin
        @config = YAML.load_file(options[:config])
      rescue SyntaxError => e
        DockerBoss.logger.fatal "Error loading config: #{e.message}"
        exit 1
      end
    end
  end
end
