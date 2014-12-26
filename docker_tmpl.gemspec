# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'docker_tmpl/version'

Gem::Specification.new do |spec|
  spec.name          = "docker_tmpl"
  spec.version       = DockerTmpl::VERSION
  spec.authors       = ["Alex Hornung"]
  spec.email         = ["alex@alexhornung.com"]
  spec.description   = %q{Templating using docker container information}
  spec.summary       = %q{Templating using docker container information}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "docker-api", "~> 1.17.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.4.2"
end
