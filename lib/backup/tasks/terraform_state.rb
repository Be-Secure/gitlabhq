# frozen_string_literal: true

module Backup
  module Tasks
    class TerraformState < Task
      def self.id = 'terraform_state'

      def human_name = _('terraform states')

      def destination_path = 'terraform_state.tar.gz'

      def target
        excludes = ['tmp']

        ::Backup::Targets::Files.new(progress, app_files_dir, options: options, excludes: excludes)
      end

      private

      def app_files_dir
        Settings.terraform_state.storage_path
      end
    end
  end
end
