require 'docker_boss'
require 'docker_boss/helpers'
require 'docker_boss/module'
require 'docker'
require 'yaml'
require 'erb'
require 'ostruct'
require 'shellwords'

class DockerBoss::Module::Templates < DockerBoss::Module
  def initialize(config)
    @config = config
    @instances = []

    config.each do |name, inst_cfg|
      @instances << Instance.new(name, inst_cfg)
    end
  end

  def trigger(containers, trigger_id)
    @instances.each do |instance|
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
    attr_reader :name

    def initialize(name, config)
      @name = name
      @config = config
      DockerBoss.logger.debug "templates: Instance `#{@name}`: created"
    end

    def do_file(f, containers)
      tmpl_path = DockerBoss::Helpers.render_erb(f['template'], :container => linked_container.json)
      file_path = DockerBoss::Helpers.render_erb(f['file'], :container => linked_container.json)

      file_contents = DockerBoss::Helpers.render_erb_file(tmpl_path, :containers => containers)

      new_digest = Digest::SHA256.hexdigest file_contents
      old_digest = (f.has_key? 'checksum') ? f['checksum'] : ""
      f['checksum'] = new_digest

      File.write(file_path, file_contents) if new_digest != old_digest
      new_digest != old_digest
    end

    def do_actions
      err = false

      if @config.has_key? 'action'
        err ||= !system(@config['action'])
      end

      if @config.has_key? 'linked_container' and @config['linked_container'].has_key? 'action'
        args = @config['linked_container']['action'].split(':', 2)
        case args.first
        when 'shell'
          raise ArgumentError, "action `shell` needs at least one more argument" if args.size < 2
          command = ["sh", "-c", args[1]]
          linked_container.exec(command)
        when 'shell_bg'
          raise ArgumentError, "action `shell_bg` needs at least one more argument" if args.size < 2
          command = ["sh", "-c", args[1]]
          linked_container.exec(command, detach: true)
        when 'exec'
          raise ArgumentError, "action `exec` needs at least one more argument" if args.size < 2
          linked_container.exec(Shellwords.split(args[1]))
        when 'exec_bg'
          raise ArgumentError, "action `exec_bg` needs at least one more argument" if args.size < 2
          linked_container.exec(Shellwords.split(args[1]), detach: true)
        when 'restart'
          linked_container.restart
        when 'start'
          linked_container.start
        when 'stop'
          linked_container.stop
        when 'pause'
          linked_container.pause
        when 'unpause'
          linked_container.unpause
        when 'kill'
          if args.size == 2
            linked_container.kill(:signal => args[1])
          else
            linked_container.kill
          end
        else
          raise ArgumentError, "unknown action `#{args.first}`"
        end
      end
    end

    def trigger(containers, trigger_id = nil)
      if trigger_id.nil? or
          not has_link? or
          linked_container.id != trigger_id
        # Only do something if the linked container is not also the triggering container
        changed = @config['files'].inject (false) { |changed,f| changed || do_file(f, containers) }
        DockerBoss.logger.info "templates: Instance `#{@name}`: triggered; changed=#{changed}"
        do_actions if changed
      else
        DockerBoss.logger.info "templates: Instance `#{@name}`: ignored event"
      end
    end

    def has_link?
      @config.has_key? 'linked_container'
    end

    def linked_container
      if has_link?
        (Docker::Container.all(:all => true).find { |c| c.json['Name'] == "/#{@config['linked_container']['name']}" })
      else
        nil
      end
    end

    def linked_container_props
      data = linked_container.json
    end
  end
end
