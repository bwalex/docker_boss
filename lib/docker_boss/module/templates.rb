require 'docker_boss'
require 'docker_boss/helpers'
require 'docker_boss/module'
require 'docker'
require 'yaml'
require 'erb'
require 'ostruct'
require 'shellwords'

class DockerBoss::Module::Templates < DockerBoss::Module::Base
  class Config
    attr_accessor :instances

    def initialize(block)
      @instances = []
      ConfigProxy.new(self).instance_eval(&block)
    end

    class ConfigProxy < ::SimpleDelegator
      def container(*args, &block)
        self.instances << DockerBoss::Module::Templates::Instance.new(args, block)
      end
    end
  end

  def self.build(&block)
    DockerBoss::Module::Templates.new(&block)
  end

  def initialize(&block)
    @config = Config.new(block)
  end

  def trigger(containers, trigger_id)
    @config.instances.each do |instance|
      begin
        instance.trigger(containers, trigger_id)
      rescue ArgumentError => e
        DockerBoss.logger.error "templates: Error in configuration for instance `#{instance.name}`: #{e.message}"
      rescue Docker::Error::DockerError => e
        DockerBoss.logger.error "templates: Error occurred processing instance `#{instance.name}`: #{e.message}"
      end
    end
  end


  class Instance
    attr_reader :patterns, :files, :actions

    def initialize(args, block)
      @patterns = args
      @block = block
      DockerBoss.logger.debug "templates: Instance `#{args.join(", ")}`: created"
    end

    class DSLProxy < ::SimpleDelegator
      include DockerBoss::Helpers::Mixin

      def file(opts)
        raise ArgumentError, "file needs both :template and :target options" unless opts.has_key? :template and opts.has_key? :target
        self.files << opts
      end

      def container_shell(c, cmd, opts = {})
        self.actions << { :action => :container_shell, :cmd => cmd, :container => c, :opts => opts }
      end

      def container_exec(c, cmd, opts = {})
        self.actions << { :action => :container_exec, :cmd => cmd, :container => c, :opts => opts }
      end

      def container_start(c, opts = {})
        self.actions << { :action => :container_start, :container => c, :opts => opts }
      end

      def container_stop(c, opts = {})
        self.actions << { :action => :container_stop, :container => c, :opts => opts }
      end

      def container_restart(c, opts = {})
        self.actions << { :action => :container_restart, :container => c, :opts => opts }
      end

      def container_pause(c, opts = {})
        self.actions << { :action => :container_pause, :container => c, :opts => opts }
      end

      def container_unpause(c, opts = {})
        self.actions << { :action => :container_unpause, :container => c, :opts => opts }
      end

      def container_kill(c, opts = {})
        self.actions << { :action => :container_kill, :container => c, :opts => opts }
      end

      def host_shell(cmd)
        self.actions << { :action => :host_shell, :cmd => cmd }
      end
    end


    def do_file(f, container, all_containers)
      tmpl_path = DockerBoss::Helpers.render_erb(f[:template], :container => container)
      file_path = DockerBoss::Helpers.render_erb(f[:target], :container => container)

      if not File.file? tmpl_path
        DockerBoss.logger.error "templates: Instance `#{@patterns.join(", ")}`: Cannot open file #{tmpl_path} (#{f[:template]})"
        return false
      end

      old_digest = (File.file? file_path) ? Digest::SHA25.hexdigest(File.read(file_path)) : ""

      file_contents = DockerBoss::Helpers.render_erb_file(tmpl_path, :container => container, :all_containers => all_containers)
      new_digest = Digest::SHA256.hexdigest file_contents

      f[:checksum] = new_digest

      File.write(file_path, file_contents) if new_digest != old_digest
      new_digest != old_digest
    end

    def do_actions
      err = false

      @actions.each do |action|
        container = find_container(action[:container]) if action.has_key? :container
        case action[:action]
        when :container_shell
          cmd = ["sh", "-c", action[:cmd]]
          container.exec(cmd, detach: action[:opts].fetch(:bg, false))
        when :container_exec
          cmd = Shellwords.split(action[:cmd])
          container.exec(cmd, detach: action[:opts].fetch(:bg, false))
        when :container_start
          container.start
        when :container_stop
          container.stop
        when :container_restart
          container.restart
        when :container_pause
          container.pause
        when :container_unpause
          container.unpause
        when :container_kill
          if action[:opts].has_key? :signal
            container.kill(signal: action[:opts][:signal])
          else
            container.kill
          end
        when :host_shell
          err ||= !system(action[:cmd])
        else
          raise ArgumentError, "unknown action `#{action[:action]}`"
        end
      end
    end

    def find_container(spec)
      c = nil

      if spec.is_a? String
        c ||= (Docker::Container.all(:all => true).find { |c| c.json['Id'] == "#{spec}" })
        c ||= (Docker::Container.all(:all => true).find { |c| c.json['Name'] == "/#{spec}" })
      elsif spec.respond_to? :json
        c ||= (Docker::Container.all(:all => true).find { |c| c.json['Id'] == "#{spec.json['Id']}" })
        c ||= (Docker::Container.all(:all => true).find { |c| c.json['Name'] == "#{spec.json['Name']}" })
      elsif spec.respond_to? :has_key and spec.has_key? 'Id'
        c ||= (Docker::Container.all(:all => true).find { |c| c.json['Id'] == "#{spec['Id']}" })
      elsif spec.respond_to? :has_key and spec.has_key? 'Name'
        c ||= (Docker::Container.all(:all => true).find { |c| c.json['Name'] == "#{spec['Name']}" })
      end

      raise IndexError, "unknown container: #{spec}" unless c != nil

      c
    end

    def trigger(containers, trigger_id = nil)
      (containers.select { |c| @patterns.inject(false) { |match,p| match || p.match(c['Name']) } }).each do |c|
        @files = []
        @actions = []
        DSLProxy.new(self).instance_exec(c, containers, &@block)
        changed = @files.inject (false) { |changed,f| do_file(f, c, containers) || changed }
        DockerBoss.logger.info "templates: Instance `#{@patterns.join(", ")}`: triggered; changed=#{changed}"
        do_actions if changed
      end
    end
  end
end
