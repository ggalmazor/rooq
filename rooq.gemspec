# frozen_string_literal: true

require_relative "lib/rooq/version"

Gem::Specification.new do |spec|
  spec.name = "rooq"
  spec.version = Rooq::VERSION
  spec.authors = ["Guillermo Galmazor"]
  spec.email = ["guillermo@galmazor.com"]

  spec.summary = "A jOOQ-inspired query builder for Ruby"
  spec.description = "Build type-safe SQL queries using a fluent, chainable API. Generate Ruby code from database schemas with optional Sorbet type annotations."
  spec.homepage = "https://github.com/ggalmazor/rooq"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github .idea docs/])
    end
  end

  spec.bindir = "exe"
  spec.executables = ["rooq"]
  spec.require_paths = ["lib"]

  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "sorbet-runtime", "~> 0.5"
end
