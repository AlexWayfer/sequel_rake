# frozen_string_literal: true

class SequelRake
	## Migration file
	class MigrationFile
		MIGRATION_CONTENT = proc do |content|
			content ||= +<<~DEFAULT
				change do
				end
			DEFAULT

			## /^(?!$)/ - searches for a position that starts at the
			## "start of line" position and
			## is not followed by the "end of line" position

			<<~STR
				# frozen_string_literal: true

				Sequel.migration do
					#{content.gsub!(/^(?!$)/, "\t").strip!}
				end
			STR
		end

		DISABLING_EXT = '.bak'

		class << self
			attr_reader :migrations_dir

			def wrap(migrations_dir)
				Class.new(self) do
					@migrations_dir = migrations_dir
				end
			end

			def find(query, only_one: true, enabled: true, disabled: true)
				filenames = Dir[File.join(@migrations_dir, "*#{query}*")]
				filenames.select! { |filename| File.file? filename }
				files = filenames.map { |filename| new filename: filename }.sort!
				files.reject!(&:disabled) unless disabled
				files.select!(&:disabled) unless enabled

				return files unless only_one
				return files.first if files.size < 2

				raise 'More than one file mathes the query'
			end
		end

		attr_reader :name, :disabled
		attr_accessor :version

		def initialize(
			filename: nil,
			name: nil,
			migration_content: nil
		)
			self.filename = filename
			self.name = name if name
			@migration_content = migration_content
		end

		## Accessors

		def basename
			File.basename(@filename)
		end

		def filename=(value)
			parse_filename value if value.is_a? String
			@filename = value
		end

		def name=(value)
			@name = value.tr(' ', '_').downcase
		end

		def disabled=(value)
			@disabled =
				case value
				when String
					[DISABLING_EXT, DISABLING_EXT[1..-1]].include? value
				else
					value
				end
		end

		def <=>(other)
			version <=> other.version
		end

		## Behavior

		def print
			datetime = Time.parse(version).strftime('%F %R')

			puts [
				Paint["[#{version}]", :white],
				Paint[datetime, disabled ? :white : :cyan],
				Paint[fullname, disabled ? :white : :default]
			].join(' ')
		end

		def generate
			self.version = new_version
			FileUtils.mkdir_p File.dirname new_filename
			File.write new_filename, MIGRATION_CONTENT.call(@migration_content)
			puts "Migration #{relative_filename} created."
		end

		def reversion
			rename version: new_version
		end

		def disable
			abort 'Migration already disabled' if disabled

			rename disabled: true

			puts "Migration #{relative_filename} disabled."
		end

		def enable
			abort 'Migration already enabled' unless disabled

			rename disabled: false

			puts "Migration #{relative_filename} enabled."
		end

		private

		def fullname
			result = name.tr('_', ' ').capitalize
			disabled ? "- #{result} (disabled)" : result
		end

		def parse_filename(value = @filename)
			basename = File.basename value
			self.version, parts = basename.split('_', 2)
			self.name, _ext, self.disabled = parts.split('.')
		end

		def new_version
			Time.now.strftime('%Y%m%d%H%M')
		end

		def rename(vars = {})
			vars.each { |key, value| send :"#{key}=", value }

			return unless @filename.is_a? String

			File.rename @filename, new_filename
			self.filename = new_filename
		end

		def new_filename
			new_basename = "#{version}_#{name}.rb#{DISABLING_EXT if disabled}"
			File.join self.class.migrations_dir, new_basename
		end

		def relative_filename
			new_filename.gsub("#{__dir__}/", '')
		end
	end
end
