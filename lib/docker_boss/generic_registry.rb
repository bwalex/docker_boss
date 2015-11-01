require 'docker_boss/version'
require 'docker_boss'

module DockerBoss::GenericRegistry
  def self.included base
    base.extend ClassMethods
    base.instance_variable_set :@registry, {}
    base.instance_variable_set :@klass, base.to_s
  end

  def self.underscore(str)
    str.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  module ClassMethods
    def <<(klass)
      self.register(klass)
    end

    def register(klass, *aliases)
      key = DockerBoss::GenericRegistry::underscore(klass.name.split('::')[-1])
      keys = [key] | aliases
      DockerBoss.logger.debug "Registering class #{key}#{aliases.empty? ? "" : " (aliases: #{aliases.join(", ")})"} for type #{@klass}"
      keys.each { |k| @registry[k.to_sym] = klass }
    end

    def [](klass)
      klass = DockerBoss::GenericRegistry::underscore(klass.to_s).to_sym

      unless @registry.has_key? klass
        path = "#{DockerBoss::GenericRegistry::underscore(@klass)}/#{klass}"

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
      raise IndexError, "Unknown class #{klass} of type #{@klass}" unless @registry.has_key? klass
      @registry[klass]
    end
  end
end
