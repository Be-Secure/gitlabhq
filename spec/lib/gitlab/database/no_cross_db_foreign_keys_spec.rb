# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'cross-database foreign keys' do
  # While we are building out Cells, we will be moving tables from gitlab_main schema
  # to either gitlab_main_clusterwide schema or gitlab_main_cell schema.
  # During this transition phase, cross database foreign keys need
  # to be temporarily allowed to exist, until we can work on converting these columns to loose foreign keys.
  # The issue corresponding to the loose foreign key conversion
  # should be added as a comment along with the name of the column.
  let!(:allowed_cross_database_foreign_keys) do
    keys = [
      'zoekt_indices.zoekt_enabled_namespace_id',
      'zoekt_repositories.project_id',
      'zoekt_replicas.zoekt_enabled_namespace_id',
      'zoekt_replicas.namespace_id',
      'system_access_microsoft_applications.namespace_id',
      'ci_runner_taggings.tag_id',                               # https://gitlab.com/gitlab-org/gitlab/-/issues/467664
      'ci_runner_taggings_instance_type.tag_id',                 # https://gitlab.com/gitlab-org/gitlab/-/issues/467664
      'ci_secure_file_states.ci_secure_file_id',                         # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'dependency_proxy_blob_states.dependency_proxy_blob_id',           # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'dependency_proxy_blob_states.group_id',                           # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'dependency_proxy_manifest_states.dependency_proxy_manifest_id',   # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'dependency_proxy_manifest_states.group_id',                       # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'lfs_objects_projects.lfs_object_id',                              # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'merge_request_diff_details.merge_request_diff_id',                # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'merge_request_diff_details.project_id',                           # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'pages_deployment_states.pages_deployment_id',                     # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'pages_deployment_states.project_id',                              # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'snippet_repositories.snippet_id',                                 # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'snippet_repositories.snippet_organization_id',                    # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'snippet_repositories.snippet_project_id',                         # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'upload_states.upload_id',                                         # https://gitlab.com/groups/gitlab-org/-/epics/17347
      'application_settings.web_ide_oauth_application_id',          # https://gitlab.com/gitlab-org/gitlab/-/issues/531355
      'ai_settings.amazon_q_oauth_application_id',                  # https://gitlab.com/gitlab-org/gitlab/-/issues/531356
      'ai_settings.duo_workflow_oauth_application_id',              # https://gitlab.com/gitlab-org/gitlab/-/issues/531356
      'ai_settings.duo_workflow_service_account_user_id',           # https://gitlab.com/gitlab-org/gitlab/-/issues/531356
      'ai_settings.amazon_q_service_account_user_id',               # https://gitlab.com/gitlab-org/gitlab/-/issues/531356
      'targeted_message_dismissals.targeted_message_id',            # https://gitlab.com/gitlab-org/gitlab/-/issues/531357
      'user_broadcast_message_dismissals.broadcast_message_id',     # https://gitlab.com/gitlab-org/gitlab/-/issues/531358
      'targeted_message_namespaces.targeted_message_id',            # https://gitlab.com/gitlab-org/gitlab/-/issues/531357
      'plan_limits.plan_id',                                        # https://gitlab.com/gitlab-org/gitlab/-/issues/519892
      'term_agreements.term_id',                                    # https://gitlab.com/gitlab-org/gitlab/-/issues/531367
      'appearance_uploads.uploaded_by_user_id',                     # https://gitlab.com/gitlab-org/gitlab/-/issues/534207
      'appearance_uploads.project_id',                              # https://gitlab.com/gitlab-org/gitlab/-/issues/534207
      'appearance_uploads.namespace_id',                            # https://gitlab.com/gitlab-org/gitlab/-/issues/534207
      'appearance_uploads.organization_id'                          # https://gitlab.com/gitlab-org/gitlab/-/issues/534207
    ]

    keys << if ::Gitlab.next_rails?
              'ci_job_artifact_states.partition_id.job_artifact_id'
            else
              'ci_job_artifact_states.partition_id'
            end

    keys
  end

  def foreign_keys_for(table_name)
    ApplicationRecord.connection.foreign_keys(table_name)
  end

  def is_cross_db?(fk_record)
    tables = [fk_record.from_table, fk_record.to_table]

    table_schemas = Gitlab::Database::GitlabSchema.table_schemas!(tables)

    !Gitlab::Database::GitlabSchema.cross_foreign_key_allowed?(table_schemas, tables)
  end

  it 'onlies have allowed list of cross-database foreign keys', :aggregate_failures do
    all_tables = ApplicationRecord.connection.data_sources
    allowlist = allowed_cross_database_foreign_keys.dup

    all_tables.each do |table|
      foreign_keys_for(table).each do |fk|
        next unless is_cross_db?(fk)

        column = "#{fk.from_table}.#{Array.wrap(fk.column).join('.')}"
        allowlist.delete(column)

        expect(allowed_cross_database_foreign_keys).to include(column), "Found extra cross-database foreign key #{column} referencing #{fk.to_table} with constraint name #{fk.name}. When a foreign key references another database you must use a Loose Foreign Key instead https://docs.gitlab.com/ee/development/database/loose_foreign_keys.html ."
      end
    end

    formatted_allowlist = allowlist.map { |item| "- #{item}" }.join("\n")
    expect(allowlist).to be_empty, "The following items must be allowed_cross_database_foreign_keys` list," \
      "as it no longer appears as cross-database foreign key:\n" \
      "#{formatted_allowlist}"
  end

  it 'only allows existing foreign keys to be present in the exempted list', :aggregate_failures do
    allowed_cross_database_foreign_keys.each do |entry|
      table, _ = entry.split('.')

      all_foreign_keys_for_table = foreign_keys_for(table)
      fk_entry = all_foreign_keys_for_table.find do |fk|
        "#{fk.from_table}.#{Array.wrap(fk.column).join('.')}" == entry
      end

      expect(fk_entry).to be_present,
        "`#{entry}` is no longer a foreign key. " \
        "You must remove this entry from the `allowed_cross_database_foreign_keys` list."
    end
  end
end
