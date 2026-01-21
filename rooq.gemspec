# frozen_string_literal: true

require_relative "lib/rooq/version"

Gem::Specification.new do |spec|
  spec.name = "rooq"
  spec.version = Rooq::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "A jOOQ-inspired query builder for Ruby"
  spec.description = "Build type-safe SQL queries using a fluent, chainable API. Generate Ruby code from database schemas with optional Sorbet type annotations."
  spec.homepage = "https://github.com/yourusername/rooq"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[test/ spec/ features/ .git .github])
    end
  end

  spec.bindir = "bin"
  spec.executables = ["rooq"]
  spec.require_paths = ["lib"]

  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "sorbet-runtime", "~> 0.5"

  spec.add_development_dependency "minitest", "~> 5.27"
  spec.add_development_dependency "minicrest", "~> 1.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "sorbet", "~> 0.5"
  spec.add_development_dependency "tapioca", "~> 0.16"
end
