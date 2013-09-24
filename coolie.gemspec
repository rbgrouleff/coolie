# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = "sisyphus"
  spec.version       = Sisyphus::VERSION
  spec.authors       = ["Rasmus Bang Grouleff"]
  spec.email         = ["rasmusbg@virtualmanager.com"]
  spec.description   = %q{A tiny library for spawning worker processes}
  spec.summary       = %q{A tiny library for spawning worker processes}
  spec.homepage      = "https://github.com/rbgrouleff/sisyphus"
  spec.license       = "Apache License 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 2.14"
end
