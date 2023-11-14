# frozen_string_literal: true

module ClickHouse
  module MigrationSupport
    # MigrationContext sets the context in which a migration is run.
    #
    # A migration context requires the path to the migrations is set
    # in the +migrations_paths+ parameter. Optionally a +schema_migration+
    # class can be provided. For most applications, +SchemaMigration+ is
    # sufficient. Multiple database applications need a +SchemaMigration+
    # per primary database.
    class MigrationContext
      attr_reader :migrations_paths, :schema_migration

      def initialize(migrations_paths, schema_migration)
        @migrations_paths = migrations_paths
        @schema_migration = schema_migration
      end

      def up(target_version = nil, &block)
        selected_migrations = block ? migrations.select(&block) : migrations

        migrate(:up, selected_migrations, target_version)
      end

      def down(target_version = nil, &block)
        selected_migrations = block ? migrations.select(&block) : migrations

        migrate(:down, selected_migrations, target_version)
      end

      private

      def migrate(direction, selected_migrations, target_version = nil)
        ClickHouse::MigrationSupport::Migrator.new(
          direction,
          selected_migrations,
          schema_migration,
          target_version
        ).migrate
      end

      def migrations
        migrations = migration_files.map do |file|
          version, name, scope = parse_migration_filename(file)

          raise ClickHouse::MigrationSupport::IllegalMigrationNameError, file unless version

          version = version.to_i
          name = name.camelize

          MigrationProxy.new(name, version, file, scope)
        end

        migrations.sort_by(&:version)
      end

      def migration_files
        paths = Array(migrations_paths)
        Dir[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
      end

      def parse_migration_filename(filename)
        File.basename(filename).scan(ClickHouse::Migration::MIGRATION_FILENAME_REGEXP).first
      end
    end

    # MigrationProxy is used to defer loading of the actual migration classes
    # until they are needed
    MigrationProxy = Struct.new(:name, :version, :filename, :scope) do
      def initialize(name, version, filename, scope)
        super
        @migration = nil
      end

      def basename
        File.basename(filename)
      end

      delegate :migrate, :announce, :write, :database, to: :migration

      private

      def migration
        @migration ||= load_migration
      end

      def load_migration
        require(File.expand_path(filename))
        name.constantize.new(name, version)
      end
    end
  end
end
