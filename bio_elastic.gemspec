# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bio_elastic/version'

Gem::Specification.new do |spec|
  spec.name          = "bio_elastic"
  spec.version       = BioElastic::VERSION
  spec.authors       = ["Kyle Campos"]
  spec.email         = ["kyle.campos@gmail.com"]
  spec.description   = %q{Interface for BioIQ's elasticsearch document store}
  spec.summary       = %q{Abstraction layer for BioIQ doc types}
  spec.homepage      = "https://github.com/BioIQ/bio_elastic"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'rspec'

  spec.add_runtime_dependency 'elasticsearch', '~>1.0.12'
end
