# frozen_string_literal: true

require_relative 'lib/sequel_rake/version'

Gem::Specification.new do |spec|
	spec.name = 'sequel_rake'

	spec.version = SequelRake::VERSION

	spec.summary = 'Rake tasks for Sequel'

	spec.authors = ['Alexander Popov']

	spec.required_ruby_version = '~> 2.3'

	spec.add_runtime_dependency 'rake_helpers', '~> 0.0'
	spec.add_runtime_dependency 'sequel', '~> 5.0'

	spec.add_development_dependency 'rubocop', '~> 0.59.2'
end
