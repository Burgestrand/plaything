# coding: utf-8
require File.expand_path("./lib/plaything/version", File.dirname(__FILE__))

Gem::Specification.new do |spec|
  spec.name          = "plaything"
  spec.summary       = "Blast raw PCM audio through your speakers using OpenAL."

  spec.homepage      = "https://github.com/Burgestrand/plaything"
  spec.authors       = ["Kim Burgestrand"]
  spec.email         = ["kim@burgestrand.se"]
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.version       = Plaything::VERSION
  spec.required_ruby_version = ">= 1.9"

  spec.add_dependency "ffi", "~> 1.1"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
