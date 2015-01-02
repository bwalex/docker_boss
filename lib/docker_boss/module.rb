require 'docker_boss'
require 'docker_boss/engine'

module DockerBoss::ModuleManager
  @modules = {}

  def self.<<(klass)
    key = klass.name.split('::')[-1].downcase
    @modules[key] = klass
  end

  def self.[](key)
    key = key.downcase

    unless @modules.has_key? key
      path = "docker_boss/module/#{key}"

      spec = Gem::Specification.find_by_path(path)
      unless spec.nil?
        activated = spec.activate
        DockerBoss.logger.info "Activated gem `#{spec.full_name}`" if activated
      end

      begin
        require path
      rescue LoadError
      end
    end

    raise IndexError, "Unknown module #{key}" unless @modules.has_key? key
    @modules[key]
  end
end

class DockerBoss::Module
  def self.inherited(klass)
    DockerBoss::ModuleManager << klass
  end

  def initialize
  end

  def run
    raise NoMethodError
  end

  def trigger(containers, trigger_id)
    raise NoMethodError
  end
end
