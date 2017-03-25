# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/pantry/version'

Gem::Specification.new do |spec|
  spec.name          = "kitchen-pantry"
  spec.version       = Kitchen::Pantry::VERSION
  spec.authors       = ["Brandon Raabe"]
  spec.email         = ["brandocorp@gmail.com"]

  spec.summary       = %q{A place to store your Kitchen's Chef data}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/brandocorp/kitchen-pantry"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'test-kitchen', '~> 1.15'

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
