# frozen_string_literal: true

require_relative "lib/rbs/patch/version"

Gem::Specification.new do |spec|
  spec.name = "rbs-patch"
  spec.version = RBS::Patch::VERSION
  spec.authors = ["Koji NAKAMURA"]
  spec.email = ["kozy4324@gmail.com"]

  spec.summary = "RBS::Patch manages RBS type definitions through patches."
  spec.description = "RBS::Patch manages RBS (Ruby Signature) type definitions through patches. " \
                     "It applies incremental changes to existing RBS signatures."
  spec.homepage = "https://github.com/kozy4324/rbs-patch"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rbs", "~> 3.0"
end
