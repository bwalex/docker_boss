require 'docker_boss/generic_registry'
require 'docker_boss'

module DockerBoss::Module
  include DockerBoss::GenericRegistry

  class Base
    def self.inherited(klass)
      DockerBoss::Module << klass
    end
  end
end
