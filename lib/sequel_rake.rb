# frozen_string_literal: true

require 'logger'
require 'sequel'
require 'fileutils'
require 'rake_helper_methods'

require_relative 'sequel_rake/migration_file'

class SequelRake
	include Rake::DSL
	include RakeHelperMethods

	def initialize(
		db_connection,
		migrations_dir: 'db/migrations',
		namespace_name: 'migrations',
		dump_task: 'db:dump'
	)
		@db_connection = db_connection
		@migrations_dir = migrations_dir
		@dump_task = dump_task

		@migration_file_class = MigrationFile.wrap(@migrations_dir)

		namespace namespace_name do
			desc 'Run migrations'
			task :run, %i[target current] do |_t, args|
				run args
			end

			desc 'Rollback the database N steps'
			task :rollback, :step do |_task, args|
				rollback args
			end

			namespace :create do
				desc 'Create regular migration'
				task :regular, %i[name migration_content] do |_t, args|
					create args
				end
			end

			alias_task :create, 'create:regular'
			alias_task :new, :create

			desc 'Change version of migration to latest'
			task :reversion, :filename do |_t, args|
				reversion args
			end

			desc 'Disable migration'
			task :disable, :filename do |_t, args|
				disable args
			end

			desc 'Enable migration'
			task :enable, :filename do |_t, args|
				enable args
			end

			desc 'Show all migrations'
			task :list do
				list
			end

			desc 'Check applied migrations'
			task :check do
				check
			end
		end

		alias_task :migrate, 'migrations:run'
	end

	private

	def run(args)
		try_to_dump

		Sequel.extension :migration

		options = {
			allow_missing_migration_files: env_true?(:ignore)
		}
		if (target = args[:target])
			if target == '0'
				puts 'Migrating all the way down'
			else
				file = @migration_file_class.find target, disabled: false

				abort 'Migration with this version not found' if file.nil?

				current = args[:current] || 'current'
				puts "Migrating from #{current} to #{file.basename}"
				target = file.version
			end
			options[:current] = args[:current].to_i
			options[:target] = target.to_i
		else
			puts 'Migrating to latest'
		end

		@db_connection.loggers << Logger.new($stdout)

		Sequel::Migrator.run @db_connection, @migrations_dir, options
	end

	def rollback(args)
		try_to_dump

		args.with_defaults(step: 1)

		step = Integer(args[:step]).abs

		file = @migration_file_class.find('*', only_one: false)[-1 - step]

		Rake::Task['db:migrations:run'].invoke(file.version)

		puts "Rolled back to #{file.basename}"
	end

	def create(args)
		abort 'You must specify a migration name' if args[:name].nil?

		file = @migration_file_class.new(
			name: args[:name],
			migration_content: args[:migration_content]
		)

		file.generate
	end

	def reversion(args)
		abort 'You must specify a migration name or version' if args[:filename].nil?

		file = @migration_file_class.find args[:filename]
		file.reversion
	end

	def disable(args)
		abort 'You must specify a migration name or version' if args[:filename].nil?

		file = @migration_file_class.find args[:filename]
		file.disable
	end

	def enable(args)
		abort 'You must specify a migration name or version' if args[:filename].nil?

		file = @migration_file_class.find args[:filename]
		file.enable
	end

	def list
		files = @migration_file_class.find '*', only_one: false
		files.each(&:print)
	end

	def check
		applied_names = @db_connection[:schema_migrations].select_map(:filename)
		applied =
			applied_names.map { |one| @migration_file_class.new filename: one }
		existing = @migration_file_class.find '*', only_one: false, disabled: false
		existing_names = existing.map(&:basename)
		a_not_e = applied.reject { |one| existing_names.include? one.basename }
		e_not_a = existing.reject { |one| applied_names.include? one.basename }

		if a_not_e.any?
			puts 'Applied, but not existing'
			a_not_e.each(&:print)
			puts "\n" if e_not_a.any?
		end

		return if e_not_a.empty?

		puts 'Existing, but not applied'
		e_not_a.each(&:print)
	end

	def try_to_dump
		Rake::Task[@dump_task].invoke if Rake::Task.task_defined?(@dump_task)
	end
end
