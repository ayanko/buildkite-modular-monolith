
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "foo1/version"

Gem::Specification.new do |spec|
  spec.name          = "foo1"
  spec.version       = Foo1::VERSION
  spec.authors       = ["Andriy Yanko"]
  spec.email         = ["andriy.yanko@gmail.com"]

  spec.summary       = %q{Foo1}

  spec.files = Dir['lib/**/*', 'README.md']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
