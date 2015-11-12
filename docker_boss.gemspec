# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'docker_boss/version'

Gem::Specification.new do |spec|
  spec.name          = "docker_boss"
  spec.version       = DockerBoss::VERSION
  spec.authors       = ["Alex Hornung"]
  spec.email         = ["alex@alexhornung.com"]
  spec.description   = %q{DockerBoss monitors docker containers for changes and triggers actions based on these changes, such as updating keys in etcd, updating DNS records, performing actions on other containers, etc.}
  spec.summary       = %q{DockerBoss monitors docker containers for changes and triggers actions based on these changes.}
  spec.homepage      = "https://github.com/bwalex/docker_boss"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_dependency "docker-api", "~> 1.22.0"
  spec.add_dependency "thor", "~> 0.19.1"
  spec.add_dependency "daemons", "~> 1.1.9"
  spec.add_dependency "rubydns", "~> 0.9.2"
  spec.add_dependency "etcd", "~> 0.2.4"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.4.2"
  spec.add_development_dependency "rspec", "~> 3.4.0"
  spec.add_development_dependency "webmock", "~> 1.22.3"
  spec.add_development_dependency "fakefs", "~> 0.6.7"
end
