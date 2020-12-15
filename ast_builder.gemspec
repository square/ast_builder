
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ast_builder/version"

Gem::Specification.new do |spec|
  spec.name          = "ast_builder"
  spec.version       = AstBuilder::VERSION
  spec.authors       = ["Brandon Weaver"]
  spec.email         = ["baweaver@squareup.com"]

  spec.summary       = %q{AstBuilder is an AST tool that makes it easier to build (and eventually manipulate) nodes}
  spec.homepage      = "https://www.github.com/baweaver/ast_builder"

  spec.license       = "Apache-2.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "guard-rspec", "~> 4.0"

  spec.add_runtime_dependency "parser", '~> 2.6.0'
  spec.add_runtime_dependency "rubocop"
end
