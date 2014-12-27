require 'docker_boss/version'
require 'celluloid'

module DockerBoss
  def self.logger
    @@logger ||= Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @@logger = logger
    Celluloid.logger = logger
  end
end
