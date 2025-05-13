# frozen_string_literal: true

require 'fast_spec_helper'
require 'fileutils'
require 'tempfile'
require_relative '../../../../../../tooling/lib/tooling/glci/failure_categories/job_trace_to_failure_category'

RSpec.describe Tooling::Glci::FailureCategories::JobTraceToFailureCategory, feature_category: :tooling do
  let(:test_dir)   { Dir.mktmpdir }
  let(:trace_path) { File.join(test_dir, 'job_trace.log') }
  let(:parser)     { described_class.new }

  after do
    FileUtils.remove_entry(test_dir)
  end

  describe '#process' do
    context 'when the job trace file is not passed to the class' do
      let(:trace_path) { nil }

      it 'returns an error' do
        result = ""
        expect { result = parser.process(trace_path) }.to output(/Error: Missing job trace file, or empty/).to_stderr
        expect(result).to eq({})
      end
    end

    context 'when the job trace file does not exist' do
      let(:trace_path) { '/nonexistent/path.log' }

      it 'returns an error' do
        result = ""
        expect { result = parser.process(trace_path) }.to output(/Error: Missing job trace file, or empty/).to_stderr
        expect(result).to eq({})
      end
    end

    context 'when the file is empty' do
      before do
        FileUtils.touch(trace_path)
      end

      it 'returns an error' do
        result = ""
        expect { result = parser.process(trace_path) }.to output(/Error: Missing job trace file, or empty/).to_stderr
        expect(result).to eq({})
      end
    end

    context 'when matching patterns' do
      before do
        FileUtils.touch(trace_path)
        File.write(trace_path, trace_content)
      end

      context 'when we cannot find a failure category' do
        let(:trace_content) do
          <<~'TRACE'
            this trace should not be matched with any failure category
          TRACE
        end

        it 'returns nil' do
          result = ""

          expect do
            result = parser.process(trace_path)
          end.to output(/\[JobTraceToFailureCategory\] Error: Could not find any failure category/).to_stderr

          expect(result).to eq({})
        end
      end

      describe 'single-line patterns' do
        describe 'danger-review job' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-07T13:51:12.206590Z 01O [GitLab Review Workload Dashboard](https://gitlab-org.gitlab.io/gitlab-roulette/)
              2025-03-07T13:51:12.206600Z 01O to find other available reviewers.
              2025-03-07T13:51:12.206610Z 01O
              2025-03-07T13:51:12.206610Z 01O **If needed, you can retry the [🔁 `danger-review` job](https://gitlab.com/gitlab-org/gitlab/-/jobs/9344192744) that generated this comment.**
              2025-03-07T13:50:56.128791Z 01E
              2025-03-07T13:51:12.249650Z 00O section_end:1741355472:step_script
              2025-03-07T13:51:12.249654Z 00O+section_start:1741355472:cleanup_file_variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "danger",
              pattern: "If needed, you can retry the.+`danger-review` job"
            })
          end
        end

        describe 'rollback of added migrations' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-03T19:21:40.309558Z 01O      ADD CONSTRAINT fk_50edc8134e FOREIGN KEY (group_id) REFERENCES namespaces(id) ON DELETE CASCADE;
              2025-02-03T19:21:40.309559Z 01O#{'  '}
              2025-02-03T19:21:40.309560Z 01O
              2025-02-03T19:21:40.309561Z 01O Error: rollback of added migrations does not revert db/structure.sql to previous state, please investigate. Apply the 'pipeline:skip-check-migrations' label to skip this check if needed.If you are unsure why this job is failing for your MR, then please refer to this page: https://docs.gitlab.com/ee/development/database/dbcheck-migrations-job.html#false-positives:
              2025-02-03T19:21:40.309565Z 01O diff --git a/db/structure.sql b/db/structure.sql
              2025-02-03T19:21:40.309566Z 01O index cb55bdb0bc..b75323ba2e 100644
              2025-02-03T19:21:40.309567Z 01O --- a/db/structure.sql
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "Error: rollback of added migrations does not " \
                "revert db/structure.sql to previous state, please investigate"
            })
          end
        end

        describe 'committed db/structure.sql does not match' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-03T15:29:23.283733Z 01O  ALTER TABLE ONLY workspace_variables
              2025-02-03T15:29:23.283734Z 01O      ADD CONSTRAINT fk_494e093520 FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;
              2025-02-03T15:29:23.283735Z 01O
              2025-02-03T15:29:23.283735Z 01O Error: the committed db/structure.sql does not match the one generated by running added migrations:
              2025-02-03T15:29:23.283736Z 01O diff --git a/db/structure.sql b/db/structure.sql
              2025-02-03T15:29:23.283737Z 01O index e729d690be..007cc238a3 100644
              2025-02-03T15:29:23.283737Z 01O --- a/db/structure.sql
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "the committed db/structure.sql does not match the one generated by running added migrations"
            })
          end
        end

        describe 'committed files in db/schema_migrations do not match' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-24T12:33:34.933213Z 01O $ git add -A -n db/schema_migrations
              2025-02-24T12:33:35.371750Z 01O add 'db/schema_migrations/20250224063503'
              2025-02-24T12:33:35.371790Z 01O
              2025-02-24T12:33:35.371800Z 01O Error: the committed files in db/schema_migrations do not match those expected by the added migrations:
              2025-02-24T12:33:35.371810Z 01O add 'db/schema_migrations/20250224063503'
              2025-02-24T12:33:35.412318Z 00O section_end:1740400415:step_script
              2025-02-24T12:33:35.412324Z 00O+section_start:1740400415:cleanup_file_variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "the committed files in db/schema_migrations do not match those expected by the added migrations"
            })
          end
        end

        describe 'pending migrations' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-04T18:12:53.264710Z 01O Created database 'gitlabhq_test'
              2025-03-04T18:12:53.676030Z 01O Created database 'gitlabhq_test_ci'
              2025-03-04T18:12:53.115257Z 01O Created database 'gitlabhq_test_sec'
              2025-03-04T18:13:31.548727Z 01O You have 3 pending migrations:
              2025-03-04T18:13:31.548735Z 01O   20250206182847 QueueRemoveOrphanedVulnerabilityNotesBatchedMigration
              2025-03-04T18:13:31.548736Z 01O   20250206182847 QueueRemoveOrphanedVulnerabilityNotesBatchedMigration
              2025-03-04T18:13:31.548738Z 01O   20250206182847 QueueRemoveOrphanedVulnerabilityNotesBatchedMigration
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "You have.+pending migrations"
            })
          end
        end

        describe 'Column operations' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-22T10:54:12.811831Z 01O db/post_migrate/20240419140530_set_trusted_extern_uid_to_false_for_existing_bitbucket_identities.rb
              2025-01-22T10:54:12.811832Z 01O db/post_migrate/20250121161403_add_ai_code_suggestions_foreign_key.rb
              2025-01-22T10:54:12.811833Z 01O
              2025-01-22T10:54:12.840008Z 01O Error: Column operations, like dropping, renaming or primary key conversion, require columns to be ignored in
              2025-01-22T10:54:12.840010Z 01O the model. This step is necessary because Rails caches the columns and re-uses it in various places across the
              2025-01-22T10:54:12.840011Z 01O application. Refer to these pages for more information:
              2025-01-22T10:54:12.840012Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "Column operations, like dropping, renaming or primary key conversion"
            })
          end
        end

        describe 'createdb error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-27T17:49:59.818098Z 01O Created database 'gitlabhq_test'
              2025-01-27T17:49:59.849740Z 01O Created database 'gitlabhq_test_ci'
              2025-01-27T17:49:36.581777Z 01E ==> 'bundle exec rake db:drop db:create db:schema:load db:migrate gitlab:db:lock_writes' succeeded in 66 seconds.
              2025-01-27T17:50:42.348795Z 01E createdb: error: database creation failed: ERROR:  database "praefect_test" already exists
              2025-01-27T17:50:42.411202Z 01O SELECT pg_catalog.set_config('search_path', '', false);
              2025-01-27T17:50:42.411205Z 01O CREATE DATABASE praefect_test ENCODING 'UTF8';
              2025-01-27T17:50:42.670715Z 00O section_end:1738000242:step_script
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "createdb: error:"
            })
          end
        end

        describe 'batched migration should be finalized' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-14T22:10:23.526212Z 01E rake aborted!
              2025-01-14T22:10:23.526306Z 01E StandardError: An error has occurred, all later migrations canceled:
              2025-01-14T22:10:23.526308Z 01E
              2025-01-14T22:10:23.526309Z 01E Batched migration should be finalized only after at-least one required stop from queuing it.
              2025-01-14T22:10:23.526310Z 01E  This is to ensure that we are not breaking the upgrades for self-managed instances.
              2025-01-14T22:10:23.526312Z 01E
              2025-01-14T22:10:23.526312Z 01E  For more info visit: https://docs.gitlab.com/ee/development/database/batched_background_migrations.html#finalize-a-batched-background-migration
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_migrations",
              pattern: "Batched migration should be finalized only after at-least one required stop from queuing it"
            })
          end
        end

        describe 'table is write protected within gitlab database' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T14:42:48.663239Z 01O      Failure/Error: connection.public_send(...)
              2025-01-29T14:42:48.663241Z 01O
              2025-01-29T14:42:48.663242Z 01O      ActiveRecord::StatementInvalid:
              2025-01-29T14:42:48.663244Z 01O        PG::SREModifyingSqlDataNotPermitted: ERROR:  Table: "ci_namespace_mirrors" is write protected within this Gitlab database.
              2025-01-29T14:42:48.663247Z 01O        HINT:  Make sure you are using the right database connection
              2025-01-29T14:42:48.663248Z 01O        CONTEXT:  PL/pgSQL function gitlab_schema_prevent_write() line 4 at RAISE
              2025-01-29T14:42:48.663250Z 01O      # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `public_send'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_table_write_protected",
              pattern: "Table.+is write protected within this Gitlab database"
            })
          end
        end

        describe 'cross-joins not supported' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-11T08:46:52.954245Z 01O   1) Gitlab::BackgroundMigration::BackfillCiBuildNeedsProjectId performs without error
              2025-02-11T08:46:52.954248Z 01O      Failure/Error:
              2025-02-11T08:46:52.954249Z 01O        raise CrossJoinAcrossUnsupportedTablesError,
              2025-02-11T08:46:52.954252Z 01O          "Unsupported cross-join across '#{tables.join(', ')}' querying '#{schemas.to_a.join(', ')}' discovered " \
              2025-02-11T08:46:52.954254Z 01O          "when executing query '#{sql}'. Please refer to https://docs.gitlab.com/ee/development/database/multiple_databases.html#removing-joins-between-ci_-and-non-ci_-tables for details on how to resolve this exception."
              2025-02-11T08:46:52.954258Z 01O
              2025-02-11T08:46:52.954259Z 01O      StandardError:
              2025-02-11T08:46:52.954260Z 01O        An error has occurred, all later migrations canceled:
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_table_write_protected",
              pattern: "Unsupported cross-join across"
            })
          end
        end

        describe 'cross schema access error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-11T13:00:43.636754Z 01O   1) Gitlab::BackgroundMigration::BackfillVulnerabilityOccurrenceIdentifiersProjectId constructs a valid query
              2025-02-11T13:00:43.636782Z 01O      Failure/Error: raise CrossSchemaAccessError, message
              2025-02-11T13:00:43.636784Z 01O
              2025-02-11T13:00:43.636785Z 01O      Gitlab::Database::QueryAnalyzers::GitlabSchemasValidateConnection::CrossSchemaAccessError:
              2025-02-11T13:00:43.636787Z 01O        The query tried to access ["vulnerability_occurrence_identifiers"] (of gitlab_sec) which is outside of allowed schemas ([:gitlab_internal, :gitlab_main, :gitlab_main_cell, :gitlab_main_clusterwide, :gitlab_pm, :gitlab_shared]) for the current connection 'main'
              2025-02-11T13:00:43.636792Z 01O      Shared Example Group: "desired sharding key backfill job" called from ./spec/lib/gitlab/background_migration/backfill_vulnerability_occurrence_identifiers_project_id_spec.rb:8
              2025-02-11T13:00:43.636794Z 01O      # ./lib/gitlab/database/query_analyzers/gitlab_schemas_validate_connection.rb:43:in `analyze'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_cross_schema_access",
              pattern: "Gitlab::Database::QueryAnalyzers::GitlabSchemasValidateConnection::CrossSchemaAccessError"
            })
          end
        end

        describe 'database connection made error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-12T20:51:50.733130Z 01O
              2025-02-12T20:51:50.733131Z 01O RuntimeError:
              2025-02-12T20:51:50.733131Z 01O   Database connection should not be called during initializers. Read more at https://docs.gitlab.com/ee/development/rails_initializers.html#database-connections-in-initializers
              2025-02-12T20:51:50.733133Z 01O # ./lib/initializer_connections.rb:32:in `raise_database_connection_made_error'
              2025-02-12T20:51:50.733134Z 01O # ./lib/initializer_connections.rb:26:in `raise_if_new_database_connection'
              2025-02-12T20:51:50.733136Z 01O # ./config/routes.rb:6:in `<top (required)>'
              2025-02-12T20:51:50.733136Z 01O # ./vendor/ruby/3.3.0/gems/railties-7.0.8.7/lib/rails/application/routes_reloader.rb:50:in `load'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "db_connection_in_rails_initializer",
              pattern: "raise_database_connection_made_error"
            })
          end
        end

        describe 'added to database dictionary' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T23:29:14.960738Z 01O      Failure/Error:
              2025-01-29T23:29:14.960739Z 01O        self.table_schema(name) || raise(
              2025-01-29T23:29:14.960741Z 01O          UnknownSchemaError,
              2025-01-29T23:29:14.960742Z 01O          "Could not find gitlab schema for table #{name}: Any new or deleted tables must be added to the database dictionary " \
              2025-01-29T23:29:14.960744Z 01O          "See https://docs.gitlab.com/ee/development/database/database_dictionary.html"
              2025-01-29T23:29:14.960799Z 01O        )
              2025-01-29T23:29:14.960801Z 01O
              2025-01-29T23:29:14.960802Z 01O      StandardError:
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_not_in_database_dictionary",
              pattern: "Any new or deleted tables must be added to the database dictionary"
            })
          end
        end

        describe 'no foreign key for' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-24T15:32:09.971926Z 01O      StandardError:
              2025-02-24T15:32:09.971927Z 01O        An error has occurred, all later migrations canceled:
              2025-02-24T15:32:09.971928Z 01O
              2025-02-24T15:32:09.971928Z 01O        Table 'snippet_repository_states' has no foreign key for {:column=>:snippet_id}
              2025-02-24T15:32:09.971929Z 01O      # ./db/migrate/20250213211743_add_foreign_key_to_snippet_repository_states_snippet_id.rb:18:in `block in down'
              2025-02-24T15:32:09.971930Z 01O      # ./lib/gitlab/database/with_lock_retries.rb:123:in `run_block'
              2025-02-24T15:32:09.971931Z 01O      # ./lib/gitlab/database/with_lock_retries.rb:134:in `block in run_block_with_lock_timeout'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_no_foreign_key",
              pattern: "has no foreign key for"
            })
          end
        end

        describe 'active sql transaction' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-14T10:24:33.581049Z 01O      1.2) Failure/Error: connection.public_send(...)
              2025-02-14T10:24:33.581049Z 01O
              2025-02-14T10:24:33.581050Z 01O           ActiveRecord::StatementInvalid:
              2025-02-14T10:24:33.581059Z 01O             PG::ActiveSqlTransaction: ERROR:  CREATE INDEX CONCURRENTLY cannot run inside a transaction block
              2025-02-14T10:24:33.581060Z 01O           # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `public_send'
              2025-02-14T10:24:33.581061Z 01O           # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `block in write_using_load_balancer'
              2025-02-14T10:24:33.581062Z 01O           # ./lib/gitlab/database/load_balancing/load_balancer.rb:141:in `block in read_write'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_active_sql_transaction",
              pattern: "PG::ActiveSqlTransaction"
            })
          end
        end

        describe 'check violation' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-17T20:39:15.985602Z 01O      Failure/Error: connection.public_send(...)
              2025-02-17T20:39:15.985604Z 01O
              2025-02-17T20:39:15.985605Z 01O      ActiveRecord::StatementInvalid:
              2025-02-17T20:39:15.985606Z 01O        PG::CheckViolation: ERROR:  new row for relation "project_security_settings" violates check constraint "check_20a23efdb6"
              2025-02-17T20:39:15.985609Z 01O        DETAIL:  Failing row contains (1, 2025-02-17 20:39:03.143462+00, 2025-02-17 20:39:03.143462+00, t, t, t, t, f, f, t, null).
              2025-02-17T20:39:15.985611Z 01O      # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `public_send'
              2025-02-17T20:39:15.985613Z 01O      # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `block in write_using_load_balancer'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_check_violation",
              pattern: "PG::CheckViolation"
            })
          end
        end

        describe 'dependent objects still exist' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-19T15:27:54.919264Z 01O      StandardError:
              2025-02-19T15:27:54.919265Z 01O        An error has occurred, this and all later migrations canceled:
              2025-02-19T15:27:54.919267Z 01O
              2025-02-19T15:27:54.919268Z 01O        PG::DependentObjectsStillExist: ERROR:  cannot drop table ai_active_context_connections because other objects depend on it
              2025-02-19T15:27:54.919271Z 01O        DETAIL:  constraint fk_rails_52b6529477 on table ai_active_context_migrations depends on table ai_active_context_connections
              2025-02-19T15:27:54.919274Z 01O        HINT:  Use DROP ... CASCADE to drop the dependent objects too.
              2025-02-19T15:27:54.919275Z 01O      # ./lib/gitlab/database/migration_helpers/restrict_gitlab_schema.rb:33:in `block in exec_migration'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_dependent_objects_still_exist",
              pattern: "PG::DependentObjectsStillExist"
            })
          end
        end

        describe 'duplicate alias' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-16T14:00:24.128593Z 01O      Failure/Error: connection.public_send(...)
              2025-01-16T14:00:24.128595Z 01O
              2025-01-16T14:00:24.128596Z 01O      ActiveRecord::StatementInvalid:
              2025-01-16T14:00:24.128598Z 01O        PG::DuplicateAlias: ERROR:  table name "vulnerability_statistics" specified more than once
              2025-01-16T14:00:24.128600Z 01O      # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `public_send'
              2025-01-16T14:00:24.128602Z 01O      # ./lib/gitlab/database/load_balancing/connection_proxy.rb:127:in `block in write_using_load_balancer'
              2025-01-16T14:00:24.128605Z 01O      # ./lib/gitlab/database/load_balancing/load_balancer.rb:141:in `block in read_write'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_duplicate_alias",
              pattern: "PG::DuplicateAlias"
            })
          end
        end

        describe 'duplicate table' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-23T10:23:44.155176Z 01O      StandardError:
              2025-01-23T10:23:44.155176Z 01O        An error has occurred, this and all later migrations canceled:
              2025-01-23T10:23:44.155177Z 01O
              2025-01-23T10:23:44.155178Z 01O        PG::DuplicateTable: ERROR:  relation "subscription_provision_syncs" already exists
              2025-01-23T10:23:44.155179Z 01O      # ./lib/gitlab/database/migration_helpers/v2.rb:28:in `create_table'
              2025-01-23T10:23:44.155180Z 01O      # ./db/post_migrate/20250116141551_drop_table_subscription_provision_syncs.rb:13:in `down'
              2025-01-23T10:23:44.155181Z 01O      # ./lib/gitlab/database/migration_helpers/restrict_gitlab_schema.rb:33:in `block in exec_migration'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_duplicate_table",
              pattern: "PG::DuplicateTable"
            })
          end
        end

        describe 'invalid column reference' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-28T08:01:39.531054Z 01O      Failure/Error: connection.public_send(...)
              2025-01-28T08:01:39.531056Z 01O
              2025-01-28T08:01:39.531056Z 01O      ActiveRecord::StatementInvalid:
              2025-01-28T08:01:39.531058Z 01O        PG::InvalidColumnReference: ERROR:  for SELECT DISTINCT, ORDER BY expressions must appear in select list
              2025-01-28T08:01:39.531059Z 01O        LINE 1: ...230 AND ("todos"."state" IN ('pending')) ORDER BY "todos"."c...
              2025-01-28T08:01:39.531061Z 01O                                                                     ^
              2025-01-28T08:01:39.531063Z 01O      # ./lib/gitlab/database/load_balancing/connection_proxy.rb:107:in `public_send'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_invalid_column_reference",
              pattern: "PG::InvalidColumnReference"
            })
          end
        end

        describe 'undefined column' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-28T00:24:47.109632Z 01O      StandardError:
              2025-01-28T00:24:47.109632Z 01O        An error has occurred, this and all later migrations canceled:
              2025-01-28T00:24:47.109633Z 01O
              2025-01-28T00:24:47.109634Z 01O        PG::UndefinedColumn: ERROR:  column "project_id" of relation "merge_request_diff_files_99208b8fac" does not exist
              2025-01-28T00:24:47.109636Z 01O      Shared Example Group: "desired sharding key backfill job" called from ./spec/lib/gitlab/background_migration/backfill_deployment_approvals_project_id_spec.rb:8
              2025-01-28T00:24:47.109637Z 01O      # ./db/migrate/20240802203135_add_project_id_to_merge_request_diff_files99208b8fac.rb:11:in `down'
              2025-01-28T00:24:47.109638Z 01O      # ./lib/gitlab/database/migration_helpers/restrict_gitlab_schema.rb:33:in `block in exec_migration'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_undefined_column",
              pattern: "PG::UndefinedColumn"
            })
          end
        end

        describe 'undefined table' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-17T08:38:53.768351Z 01O      StandardError:
              2025-01-17T08:38:53.768352Z 01O        An error has occurred, this and all later migrations canceled:
              2025-01-17T08:38:53.768353Z 01O
              2025-01-17T08:38:53.768353Z 01O        PG::UndefinedTable: ERROR:  table "encryption_keys" does not exist
              2025-01-17T08:38:53.768354Z 01O      # ./lib/gitlab/database/migration_helpers/restrict_gitlab_schema.rb:33:in `block in exec_migration'
              2025-01-17T08:38:53.768355Z 01O      # ./lib/gitlab/database/query_analyzer.rb:83:in `within'
              2025-01-17T08:38:53.768356Z 01O      # ./lib/gitlab/database/migration_helpers/restrict_gitlab_schema.rb:30:in `exec_migration'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_undefined_table",
              pattern: "PG::UndefinedTable"
            })
          end
        end

        describe 'unrouted sidekiq api error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-17T17:45:11.479400Z 01O      # ./spec/support/database/prevent_cross_joins.rb:106:in `block (2 levels) in <top (required)>'
              2025-02-17T17:45:11.479420Z 01O      # ------------------
              2025-02-17T17:45:11.479430Z 01O      # --- Caused by: ---
              2025-02-17T17:45:11.479440Z 01O      # Gitlab::SidekiqSharding::Validator::UnroutedSidekiqApiError:
              2025-02-17T17:45:11.479450Z 01O      #   Sidekiq Redis called outside a .via block
              2025-02-17T17:45:11.479460Z 01O      #   ./lib/gitlab/error_tracking.rb:82:in `track_and_raise_for_dev_exception'
              2025-02-17T17:45:11.487000Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_pg_sidekiq",
              pattern: "Gitlab::SidekiqSharding::Validator::UnroutedSidekiqApiError"
            })
          end
        end

        describe 'psql command failure' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-04T18:37:20.320844Z 01O Dropped database 'gitlabhq_production_ci'
              2025-02-04T18:37:20.320845Z 01O Created database 'gitlabhq_production'
              2025-02-04T18:37:20.320846Z 01O Created database 'gitlabhq_production_ci'
              2025-02-04T18:37:24.618980Z 01E psql:/builds/gitlab-org/gitlab/db/structure.sql:37846: ERROR:  function trigger_ff16c1fd43ea() does not exist
              2025-02-04T18:37:24.630439Z 01E rake aborted!
              2025-02-04T18:37:24.630445Z 01E failed to execute:
              2025-02-04T18:37:24.630446Z 01E psql --set ON_ERROR_STOP=1 --quiet --no-psqlrc --output /dev/null --file /builds/gitlab-org/gitlab/db/structure.sql --single-transaction gitlabhq_production
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "psql_failed_command",
              pattern: "psql:.+ERROR:"
            })
          end
        end

        describe 'unallowed schemas accessed' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-05T09:24:14.449023Z 01O          "which is outside of list of allowed schemas: '#{allowed_gitlab_schemas}'. " \
              2025-03-05T09:24:14.449024Z 01O          "#{documentation_url}"
              2025-03-05T09:24:14.449025Z 01O
              2025-03-05T09:24:14.449025Z 01O      Gitlab::Database::QueryAnalyzers::RestrictAllowedSchemas::DMLAccessDeniedError:
              2025-03-05T09:24:14.449027Z 01O        Select/DML queries (SELECT/UPDATE/DELETE) do access '["ci_runners"]' ([:gitlab_ci]) which is outside of list of allowed schemas: '[:gitlab_main]'. For more information visit: https://docs.gitlab.com/ee/development/database/migrations_for_multiple_databases.html
              2025-03-05T09:24:14.449029Z 01O      # ./lib/gitlab/database/query_analyzers/restrict_allowed_schemas.rb:90:in `restrict_to_dml_only'
              2025-03-05T09:24:14.449051Z 01O      # ./lib/gitlab/database/query_analyzers/restrict_allowed_schemas.rb:45:in `analyze'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rake_unallowed_schemas_accessed",
              pattern: "Gitlab::Database::QueryAnalyzers::RestrictAllowedSchemas::DMLAccessDeniedError:"
            })
          end
        end

        describe 'enqueue from transaction error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-05T23:58:32.194289Z 01O
              2025-02-05T23:58:32.194291Z 01O == Seed from db/fixtures/development/16_protected_branches.rb
              2025-02-05T23:58:32.297687Z 01E rake aborted!
              2025-02-05T23:58:32.297692Z 01E Sidekiq::Job::EnqueueFromTransactionError: Security::SyncPolicyEventWorker.perform_async cannot be enqueued inside a transaction as this can lead to
              2025-02-05T23:58:32.297730Z 01E race conditions when the worker runs before the transaction is committed and
              2025-02-05T23:58:32.297731Z 01E tries to access a model that has not been saved yet.
              2025-02-05T23:58:32.297732Z 01E
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rake_enqueue_from_transaction",
              pattern: "Sidekiq::Job::EnqueueFromTransactionError"
            })
          end
        end

        describe 'unknown schema error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-26T10:45:43.818340Z 01E Embedding DB won't be set up.
              2025-02-26T10:45:43.870304Z 01O $ bundle exec rake gitlab:graphql:schema:dump
              2025-02-26T10:45:43.819879Z 01E rake aborted!
              2025-02-26T10:46:02.496029Z 01E Gitlab::Database::GitlabSchema::UnknownSchemaError: /builds/gitlab-org/gitlab-foss/db/docs/catalogs.yml must specify a valid gitlab_schema for catalogs. See https://docs.gitlab.com/ee/development/database/database_dictionary.html
              2025-02-26T10:46:02.496085Z 01E /builds/gitlab-org/gitlab-foss/lib/gitlab/database/dictionary.rb:148:in `validate!'
              2025-02-26T10:46:02.496087Z 01E <internal:kernel>:90:in `tap'
              2025-02-26T10:46:02.496089Z 01E /builds/gitlab-org/gitlab-foss/lib/gitlab/database/dictionary.rb:36:in `block in entries'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rake_db_unknown_schema",
              pattern: "Gitlab::Database::GitlabSchema::UnknownSchemaError"
            })
          end
        end

        describe 'unknown primary key' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-14T05:58:02.758904Z 01O       loads the correct records
              2025-02-14T05:58:02.812923Z 01O       does not use the function-based finder query
              2025-02-14T05:58:02.812966Z 01O     when there is no primary key defined
              2025-02-14T05:58:02.846955Z 01O       raises ActiveRecord::UnknownPrimaryKey
              2025-02-14T05:58:02.846996Z 01O     when id is provided as an array
              2025-02-14T05:58:02.902134Z 01O       returns the correct record as an array
              2025-02-14T05:58:02.958586Z 01O       does use the function-based finder query
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rake_rails_unknown_primary_key",
              pattern: "ActiveRecord::UnknownPrimaryKey"
            })
          end
        end

        describe 'error in db migration this and all later migrations canceled' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-05T14:06:39.753708Z 01O      Failure/Error: super
              2025-02-05T14:06:39.753709Z 01O
              2025-02-05T14:06:39.753710Z 01O      StandardError:
              2025-02-05T14:06:39.753712Z 01O        An error has occurred, this and all later migrations canceled:
              2025-02-05T14:06:39.753714Z 01O
              2025-02-05T14:06:39.753715Z 01O        No indexes found on security_pipeline_execution_project_schedules with the options provided.
              2025-02-05T14:06:39.753734Z 01O      # ./lib/gitlab/database/migration_helpers/restrict_gitlab_schema.rb:33:in `block in exec_migration'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "error_in_db_migration",
              pattern: "An error has occurred, this and all later migrations canceled"
            })
          end
        end

        describe 'error in db migration all later migrations canceled' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T20:59:28.899660Z 01O      Failure/Error: execute('RESET statement_timeout')
              2025-01-29T20:59:28.899670Z 01O
              2025-01-29T20:59:28.899680Z 01O      StandardError:
              2025-01-29T20:59:28.899690Z 01O        An error has occurred, all later migrations canceled:
              2025-01-29T20:59:28.899700Z 01O
              2025-01-29T20:59:28.899700Z 01O
              2025-01-29T20:59:28.899710Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "error_in_db_migration",
              pattern: "An error has occurred, all later migrations canceled"
            })
          end
        end

        describe 'invalid sql statement' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-20T07:09:35.701584Z 01O Created database 'gitlabhq_test'
              2025-02-20T07:09:35.741141Z 01O Created database 'gitlabhq_test_ci'
              2025-02-20T07:09:08.101070Z 01E rake aborted!
              2025-02-20T07:10:23.938079Z 01E ActiveRecord::StatementInvalid: PG::WrongObjectType: ERROR:  "remote_development_namespace_cluster_agent_mappings" is a view
              2025-02-20T07:10:23.938083Z 01E DETAIL:  Views cannot have TRUNCATE triggers.
              2025-02-20T07:10:23.938711Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/activerecord-7.0.8.7/lib/active_record/connection_adapters/postgresql/database_statements.rb:48:in `exec'
              2025-02-20T07:10:23.938714Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/activerecord-7.0.8.7/lib/active_record/connection_adapters/postgresql/database_statements.rb:48:in `block (2 levels) in execute'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rails_invalid_sql_statement",
              pattern: "ActiveRecord::StatementInvalid"
            })
          end
        end

        describe 'graphql needs to be regenerated' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-20T12:28:16.105275Z 01O Schema JSON dumped into /builds/gitlab-org/gitlab/tmp/tests/graphql/gitlab_schema.json
              2025-01-20T12:28:16.214474Z 01O $ node scripts/frontend/graphql_possible_types_extraction.js --check
              2025-01-20T12:28:19.843682Z 01E
              2025-01-20T12:28:19.843697Z 01E app/assets/javascripts/graphql_shared/possible_types.json needs to be regenerated, please run:
              2025-01-20T12:28:19.843699Z 01E     node scripts/frontend/graphql_possible_types_extraction.js --write
              2025-01-20T12:28:19.843701Z 01E and commit the changes!
              2025-01-20T12:28:19.843702Z 01E#{'     '}
              2025-01-20T12:28:19.844183Z 01E AssertionError [ERR_ASSERTION]:
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "graphql_lint",
              pattern: "needs to be regenerated, please run:"
            })
          end
        end

        describe 'graphql query failed validation' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-23T12:58:06.291746Z 01E OK    /builds/gitlab-org/gitlab/ee/app/assets/javascripts/workspaces/user/graphql/queries/search_projects.query.graphql
              2025-01-23T12:58:06.292301Z 01O ##########
              2025-01-23T12:58:06.292306Z 01O #
              2025-01-23T12:58:06.292307Z 01O # 1 GraphQL query out of 1302 failed validation:
              2025-01-23T12:58:06.292309Z 01O # - /builds/gitlab-org/gitlab/app/assets/javascripts/token_access/graphql/queries/get_ci_job_token_scope_allowlist.query.graphql
              2025-01-23T12:58:06.292311Z 01O #
              2025-01-23T12:58:06.292311Z 01O ##########
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "graphql_lint",
              pattern: "GraphQL quer.+out of.+failed validation:"
            })
          end
        end

        describe 'eslint.js gitlab' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-28T23:11:59.188266Z 01O $ run_timed_command "yarn run lint:eslint:all --format gitlab"
              2025-01-28T23:11:53.861625Z 01E $ yarn run lint:eslint:all --format gitlab
              yarn run v1.22.19
              $ node scripts/frontend/eslint.js . --format gitlab
              $ eslint --cache --max-warnings 0 --report-unused-disable-directives . --format gitlab
              2025-01-28T23:12:11.786772Z 01O IncrementalWebpackCompiler: Status – disabled
              2025-01-28T23:22:21.479733Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "eslint",
              pattern: "node scripts/frontend/eslint.js . --format gitlab"
            })
          end
        end

        describe 'eslint rules enabled' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-17T21:36:53.445410Z 01O $ run_timed_command "scripts/frontend/lint_docs_links.mjs"
              2025-01-17T21:36:51.372737Z 01E $ scripts/frontend/lint_docs_links.mjs
              2025-01-17T21:36:53.452708Z 01O Running ESLint with the following rules enabled:
              2025-01-17T21:36:53.452723Z 01O * local-rules/require-valid-help-page-path
              2025-01-17T21:36:53.452725Z 01O * local-rules/vue-require-valid-help-page-link-component
              2025-01-17T21:37:24.623161Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "eslint",
              pattern: "Running ESLint with the following rules enabled"
            })
          end
        end

        describe 'docs lint tests failed' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-06T01:50:21.648840Z 01O 1 errors, 0 warnings, and 0 suggestions found in 1 file.
              2025-02-06T01:50:21.735100Z 01E ERROR: 'vale' failed with errors!
              2025-02-06T01:50:21.736490Z 01O
              2025-02-06T01:50:21.736500Z 01O ERROR: lint test(s) failed! Review the log carefully to see full listing.
              2025-02-06T01:50:21.230171Z 00O section_end:1738806621:step_script
              2025-02-06T01:50:21.230176Z 00O+section_start:1738806621:cleanup_file_variables
              2025-02-06T01:50:21.232605Z 00O+Cleaning up project directory and file based variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_lint_failed",
              pattern: "ERROR: lint test\\(s\\) failed.+Review the log carefully to see full listing"
            })
          end
        end

        describe 'files inspected with lints detected' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-13T00:14:07.788742Z 01E $ bundle exec haml-lint --parallel app/views
              2025-02-13T00:15:13.966171Z 01O app/views/projects/pipelines/show.html.haml:35 [W] DocumentationLinks: help_page_path points to the unknown location: /builds/gitlab-org/gitlab/doc/user/application_security/dependency_scanning/migration_guide_to_sbom_based_scans.md
              2025-02-13T00:15:13.966177Z 01O
              2025-02-13T00:15:13.966178Z 01O 1480 files inspected, 1 lint detected
              2025-02-13T00:14:07.845239Z 01E /usr/bin/bash: line 426: pop_var_context: head of shell_variables not a function context
              2025-02-13T00:15:14.169203Z 00O section_end:1739405714:step_script
              2025-02-13T00:15:14.169208Z 00O+section_start:1739405714:upload_artifacts_on_failure
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_lint_failed",
              pattern: "files inspected,.+lints? detected"
            })
          end
        end

        describe 'issues found in input' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-10T16:53:50.514868Z 01O $ lychee --offline --no-progress --include-fragments doc
              2025-02-10T16:53:51.736180Z 01E    [ERROR] file:///builds/gitlab-org/gitlab/doc/user/gitlab_duo/tutorials/fix_code_python_shop.md#do-the-first-task
              2025-02-10T16:53:51.737570Z 01E    [ERROR] file:///builds/gitlab-org/gitlab/doc/subscriptions/subscription-add-ons.md#assign-gitlab-duo-pro-seats
              2025-02-10T16:53:51.870795Z 01O Issues found in 1 input. Find details below.
              2025-02-10T16:53:51.870801Z 01O
              2025-02-10T16:53:51.870802Z 01O [doc/user/gitlab_duo/tutorials/fix_code_python_shop.md]:
              2025-02-10T16:53:51.870804Z 01O    [ERROR] file:///builds/gitlab-org/gitlab/doc/subscriptions/subscription-add-ons.md#assign-gitlab-duo-pro-seats | Cannot find fragment
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_lint_failed",
              pattern: "Issues found in .+input.+Find details below."
            })
          end
        end

        describe 'lint-docs-redirects.rb' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-28T16:12:06.722780Z 01E Geo DB won't be set up.
              2025-02-28T16:12:06.107173Z 01E Embedding DB won't be set up.
              2025-02-28T16:12:06.148573Z 01O $ # For non-merge request, or when RUN_ALL_RUBOCOP is 'true', run all RuboCop rules # collapsed multi-line command
              2025-02-28T16:12:06.111158Z 01E $ fail_on_warnings bundle exec rubocop --parallel --force-exclusion scripts/lint-docs-redirects.rb
              2025-02-28T16:12:16.334510Z 01O Inspecting 1 file
              2025-02-28T16:12:16.334517Z 01O C
              2025-02-28T16:12:16.334517Z 01O
              2025-02-28T16:12:16.334518Z 01O Offenses:
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_lint_failed",
              pattern: "scripts/lint-docs-redirects.rb"
            })
          end
        end

        describe 'git diff db/docs' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-20T15:45:49.917147Z 01O CREATE DATABASE praefect_test ENCODING 'UTF8';
              2025-02-20T15:45:49.918956Z 01O $ bundle exec rake gitlab:db:dictionary:generate
              2025-02-20T15:46:38.536335Z 01O $ git diff --exit-code db/docs
              2025-02-20T15:46:38.594587Z 01O diff --git a/db/docs/taggings.yml b/db/docs/taggings.yml
              2025-02-20T15:46:38.594592Z 01O index 16ca65258..b155c731f 100644
              2025-02-20T15:46:38.594594Z 01O --- a/db/docs/taggings.yml
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_lint_failed",
              pattern: "git diff --exit-code db/docs"
            })
          end
        end

        describe 'documentation is outdated' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-06T23:05:34.259468Z 01O $ bundle exec rake gitlab:graphql:check_docs
              2025-02-06T23:06:26.632085Z 01O ##########
              2025-02-06T23:06:26.632093Z 01O #
              2025-02-06T23:06:26.632094Z 01O # GraphQL documentation is outdated! Please update it by running `bundle exec rake gitlab:graphql:compile_docs`.
              2025-02-06T23:06:26.632095Z 01O #
              2025-02-06T23:06:26.632096Z 01O ##########
              2025-02-06T23:06:27.236300Z 00O section_end:1738883187:step_script
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_outdated",
              pattern: "documentation is outdated.+Please update it by running"
            })
          end
        end

        describe 'ci-ensure-application-settings-have-definition-file.rb' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T02:22:26.481827Z 01O Using decomposed database config (config/database.yml.decomposed-postgresql)
              2025-01-29T02:22:26.482745Z 01E Geo DB won't be set up.
              2025-01-29T02:22:26.482750Z 01E Embedding DB won't be set up.
              2025-01-29T02:22:26.544755Z 01O $ run_timed_command "scripts/cells/ci-ensure-application-settings-have-definition-file.rb"
              2025-01-29T02:22:26.483866Z 01E $ scripts/cells/ci-ensure-application-settings-have-definition-file.rb
              2025-01-29T02:22:26.546152Z 01E scripts/cells/ci-ensure-application-settings-have-definition-file.rb:45:in `block (2 levels) in check_extra_definition_files!': undefined method `path' for an instance of String (NoMethodError)
              2025-01-29T02:22:26.785354Z 01E
              2025-01-29T02:22:26.785357Z 01E       stderr.puts "Definition file `#{definition_file.path}` doesn't have a corresponding attribute!"
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "cells_lint",
              pattern: "scripts/cells/ci-ensure-application-settings-have-definition-file.rb"
            })
          end
        end

        describe 'blocking Pajamas violations found' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-03T16:13:24.801869Z 01E     raise TimeoutExpired(
              2025-03-03T16:13:24.801870Z 01E subprocess.TimeoutExpired: Command '['git', 'fetch', 'https://gitlab-ci-token:[MASKED]@gitlab.com/gitlab-org/gitlab', 'master']' timed out after 300 seconds
              2025-03-03T16:13:24.801876Z 01E
              2025-03-03T16:13:24.801886Z 01E Merge request scan exit status: 2
              2025-03-03T16:13:25.553100Z 00O section_end:1741018405:step_script
              2025-03-03T16:13:25.553600Z 00O+section_start:1741018405:upload_artifacts_on_failure
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "pajamas_violations",
              pattern: "Merge request scan exit status: 2"
            })
          end
        end

        describe 'yamllint' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-15T21:32:33.781540Z 00O+section_start:1736976753:step_script
              2025-01-15T21:32:33.784947Z 00O+Executing "step_script" stage of the job script
              2025-01-15T21:32:33.787342Z 00O Using docker image sha256:6835c5b658c623f9bd3e1ca19689549ccdbb9e3ecc83f535852acd368d4d270c for pipelinecomponents/yamllint:latest with digest pipelinecomponents/yamllint@sha256:4463d2a4404860b00afacc7ce3f17cb78bd794f72cff1d06124abb4fae62f1dc ...
              2025-01-15T21:32:34.195111Z 01O $ yamllint -d "{extends: default, rules: {line-length: disable, document-start: disable}}" $LINT_PATHS
              2025-01-15T21:32:39.207871Z 01O .gitlab/ci/database.gitlab-ci.yml
              2025-01-15T21:32:39.207877Z 01O   69:58     warning  too few spaces before comment  (comments)
              2025-01-15T21:32:39.207879Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "yaml_lint_failed",
              pattern: "yamllint "
            })
          end
        end

        describe 'invalid po-files' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-18T00:58:31.755878Z 01O     translation contains < or >. Use variables to include HTML in the string, or the &lt; and &gt; codes for the symbols. For more info see: https://docs.gitlab.com/ee/development/i18n/externalization.html#html
              2025-01-18T00:58:31.755879Z 01O /builds/gitlab-org/gitlab/vendor/ruby/3.2.0/gems/io-event-1.6.5/lib/io/event/support.rb:27: warning: IO::Buffer is experimental and both the Ruby and C interface may change in the future!
              2025-01-18T00:58:31.755881Z 01O rake aborted!
              2025-01-18T00:58:31.755882Z 01O Not all PO-files are valid: /builds/gitlab-org/gitlab/locale/es/gitlab.po, /builds/gitlab-org/gitlab/locale/ko/gitlab.po, and /builds/gitlab-org/gitlab/locale/ru/gitlab.po
              2025-01-18T00:58:31.755883Z 01O /builds/gitlab-org/gitlab/lib/tasks/gettext.rake:69:in `block (2 levels) in <main>'
              2025-01-18T00:58:31.755884Z 01O Tasks: TOP => gettext:lint
              2025-01-18T00:58:31.755885Z 01O (See full trace by running task with --trace)
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rake_some_po_files_invalid",
              pattern: "Not all PO-files are valid"
            })
          end
        end

        describe 'changes in translated strings found' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-14T09:13:52.994564Z 01O Tip: For even faster regeneration, directly run the following command:
              2025-02-14T09:13:52.994565Z 01O   tooling/bin/gettext_extractor locale/gitlab.pot
              2025-02-14T09:13:52.994567Z 01O rake aborted!
              2025-02-14T09:13:52.994568Z 01O Changes in translated strings found, please update file `/builds/gitlab-org/gitlab/locale/gitlab.pot` by running:
              2025-02-14T09:13:52.994569Z 01O
              2025-02-14T09:13:52.994570Z 01O   tooling/bin/gettext_extractor locale/gitlab.pot
              2025-02-14T09:13:52.994571Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rake_outdated_translated_strings",
              pattern: "Changes in translated strings found, please update file"
            })
          end
        end

        describe 'deprecations documentation is outdated' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-11T21:16:26.795566Z 01E Geo DB won't be set up.
              2025-02-11T21:16:26.895367Z 01E Embedding DB won't be set up.
              2025-02-11T21:16:26.963795Z 01O $ bundle exec rake gitlab:docs:check_deprecations
              2025-02-11T21:16:26.897058Z 01E ERROR: Deprecations documentation is outdated!
              2025-02-11T21:16:46.979894Z 01E To update the deprecations documentation, either:
              2025-02-11T21:16:46.979898Z 01E
              2025-02-11T21:16:46.979899Z 01E - Run `bin/rake gitlab:docs:compile_deprecations` and commit the changes.
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "docs_deprecations_outdated",
              pattern: "ERROR: Deprecations documentation is outdated"
            })
          end
        end

        describe 'problems with the lockfile' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-11T18:26:15.300189Z 01O $ untamper-my-lockfile --lockfile yarn.lock
              2025-02-11T18:26:15.503702Z 01E Checking whether lockfile(s) yarn.lock have been tampered with
              2025-02-11T18:26:31.391193Z 01E Checking yarn.lock: package 2105 of 2105
              2025-02-11T18:26:31.392200Z 01E [X] Found problems with the lockfile(s):
              2025-02-11T18:26:31.392203Z 01E - ERROR yarn.lock: Could not process entry for @gitlab/ui@https://gitlab.com/gitlab-org/gitlab-ui/-/jobs/9105483836/artifacts/raw/gitlab-ui.3041-remove-bcollapse.tgz: Cannot read properties of undefined (reading 'startsWith')
              2025-02-11T18:26:31.585859Z 00O section_end:1739298391:step_script
              2025-02-11T18:26:31.585864Z 00O+section_start:1739298391:cleanup_file_variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "frontend_lockfile",
              pattern: "Found problems with the lockfile"
            })
          end
        end

        describe 'needs to be updated but yarn was run with frozen-lockfile' do
          let(:trace_content) do
            <<~'TRACE'
              warning nyc > rimraf@3.0.2: Rimraf versions prior to v4 are no longer supported
              warning nyc > istanbul-lib-processinfo > rimraf@3.0.2: Rimraf versions prior to v4 are no longer supported
              warning nyc > spawn-wrap > rimraf@3.0.2: Rimraf versions prior to v4 are no longer supported
              error Your lockfile needs to be updated, but yarn was run with `--frozen-lockfile`.
              info Visit https://yarnpkg.com/en/docs/cli/install for documentation about this command.
              2025-02-10T02:47:36.889282Z 01O [02:47:36] Retry attempts left: 2...
              yarn install v1.22.19
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "frontend_lockfile",
              pattern: "Your lockfile needs to be updated, but yarn was run with"
            })
          end
        end

        describe 'Yarn dependency issues' do
          let(:trace_content) do
            <<~'TRACE'
              warning Workspaces can only be enabled in private projects.
              [5/5] Building fresh packages...
              $ node ./scripts/frontend/postinstall.js
              2025-02-11T18:29:01.744444Z 01E error Peer dependency violation:
              2025-02-11T18:29:01.744994Z 01E @gitlab/duo-ui requires @gitlab/ui@>=106.2.0 but https://gitlab.com/gitlab-org/gitlab-ui/-/jobs/9105483836/artifacts/raw/gitlab-ui.3041-remove-bcollapse.tgz is installed
              info Visit https://yarnpkg.com/en/docs/cli/install for documentation about this command.
              error Command failed with exit code 1.
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "yarn_dependency_violation",
              pattern: "Peer dependency violation"
            })
          end
        end

        describe 'yarn run lint:prettier failed' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-28T05:02:27.683992Z 01O
              2025-02-28T05:02:27.683993Z 01O Some static analyses failed:
              2025-02-28T05:02:27.683993Z 01O
              2025-02-28T05:02:27.683994Z 01O **** yarn run lint:prettier failed with the following error(s):
              2025-02-28T05:02:27.683995Z 01O
              yarn run v1.22.19
              $ yarn run prettier --check '**/*.{graphql,js,vue}'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "yarn_run",
              pattern: "yarn run.+failed with the following error"
            })
          end
        end

        describe 'gemfile lockfile cant be updated' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-06T14:42:05.180804Z 01E Don't run Bundler as root. Installing your bundle as root will break this
              2025-03-06T14:42:05.180812Z 01E application for all non-root users on this machine.
              2025-03-06T14:42:05.310552Z 01O Patching bundler with bundler-checksum...
              2025-03-06T14:42:05.572035Z 01E The gemspecs for path gems changed, but the lockfile can't be updated because
              2025-03-06T14:42:05.572061Z 01E frozen mode is set
              2025-03-06T14:42:05.572062Z 01E
              2025-03-06T14:42:05.572063Z 01E Run `bundle install` elsewhere and add the updated Gemfile to version control.
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "changed, but the lockfile can't be updated"
            })
          end
        end

        describe 'gemfile lockfile does not satisfy dependencies' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-17T04:31:20.108099Z 01E Don't run Bundler as root. Installing your bundle as root will break this
              2025-01-17T04:31:20.108107Z 01E application for all non-root users on this machine.
              2025-01-17T04:31:20.331612Z 01O Patching bundler with bundler-checksum...
              2025-01-17T04:31:20.600394Z 01E Your lockfile does not satisfy dependencies of "gitlab-secret_detection", but
              2025-01-17T04:31:20.600402Z 01E the lockfile can't be updated because frozen mode is set
              2025-01-17T04:31:20.600405Z 01E
              2025-01-17T04:31:20.600406Z 01E Run `bundle install` elsewhere and add the updated Gemfile.next to version
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "Your lockfile does not satisfy dependencies of"
            })
          end
        end

        describe 'outdated gemfile dependencies' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-07T09:40:43.500588Z 00O+Running after_script
              2025-02-07T09:40:43.949448Z 01O Running after script...
              2025-02-07T09:40:43.949455Z 01O $ if [ "$CI_JOB_STATUS" == "failed" ]; then # collapsed multi-line command
              2025-02-07T09:40:43.949464Z 01O Gemfile.next.lock contains outdated dependencies, please run the following command and push the changes:
              2025-02-07T09:40:43.949569Z 01O bundle exec rake bundler:gemfile:sync
              2025-02-07T09:40:44.698470Z 00O section_end:1738921244:after_script
              2025-02-07T09:40:44.698520Z 00O+section_start:1738921244:cleanup_file_variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "contains outdated dependencies"
            })
          end
        end

        describe 'already activated gemfile' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-20T08:43:11.361906Z 01O ruby: warning: Ruby was built without YJIT support. You may need to install rustc to build Ruby with YJIT.
              2025-02-20T08:43:11.361907Z 01O ruby: warning: Ruby was built without YJIT support. You may need to install rustc to build Ruby with YJIT.
              2025-02-20T08:43:11.361908Z 01O /builds/gitlab-org/gitlab/vendor/ruby/3.4.0/gems/bundler-2.5.11/lib/bundler/runtime.rb:304:in 'Bundler::Runtime#check_for_activated_spec!': You have already activated json 2.9.1, but your Gemfile requires json 2.7.3. Since json is a default gem, you can either remove your dependency on it or try updating to a newer version of bundler that supports json as a default gem. (Gem::LoadError)
              2025-02-20T08:43:11.361910Z 01O 	from /builds/gitlab-org/gitlab/vendor/ruby/3.4.0/gems/bundler-2.5.11/lib/bundler/runtime.rb:25:in 'block in Bundler::Runtime#setup'
              2025-02-20T08:43:11.361911Z 01O 	from /builds/gitlab-org/gitlab/vendor/ruby/3.4.0/gems/bundler-2.5.11/lib/bundler/spec_set.rb:191:in 'Array#each'
              2025-02-20T08:43:11.361912Z 01O 	from /builds/gitlab-org/gitlab/vendor/ruby/3.4.0/gems/bundler-2.5.11/lib/bundler/spec_set.rb:191:in 'Bundler::SpecSet#each'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "You have already activated"
            })
          end
        end

        describe 'generate gemfile checksum' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-14T07:09:26.258361Z 01O Fetching nokogiri 1.18.1 (x86_64-linux-gnu)
              2025-01-14T07:09:26.696149Z 01O Installing nokogiri 1.18.1 (x86_64-linux-gnu)
              2025-01-14T07:09:26.700008Z 01E Cached checksum for nokogiri-1.18.1-x86_64-linux-gnu not found. Please
              2025-01-14T07:09:26.700012Z 01E (re-)generate Gemfile.checksum with `bundle exec bundler-checksum init`. See
              2025-01-14T07:09:26.700013Z 01E https://docs.gitlab.com/ee/development/gemfile.html#updating-the-checksum-file.
              2025-01-14T07:09:26.794633Z 01E scripts/utils.sh: line 107: pop_var_context: head of shell_variables not a function context
              2025-01-14T07:09:26.794639Z 01E scripts/prepare_build.sh: line 7: pop_var_context: head of shell_variables not a function context
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "Cached checksum for .+ not found"
            })
          end
        end

        describe 'bundler had issues installing a given gem' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-03T14:31:53.588768Z 01O Fetching rb_sys 0.9.110
              2025-02-03T14:31:53.618712Z 01O Installing haml_lint 0.60.0
              2025-02-03T14:31:53.632978Z 01O Installing rb_sys 0.9.110
              2025-02-03T14:31:53.667525Z 01E Bundler cannot continue installing gitlab-kas-grpc (17.8.1).
              2025-02-03T14:31:53.667528Z 01E The checksum for the downloaded `gitlab-kas-grpc-17.8.1.gem` does not match the
              2025-02-03T14:31:53.667529Z 01E checksum from the checksum file. This means the contents of the downloaded gem
              2025-02-03T14:31:53.667530Z 01E is different from what was recorded in the checksum file, and could be potential
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "Bundler cannot continue installing"
            })
          end
        end

        describe 'cached checksum not found' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-07T09:40:36.711840Z 01O Fetching gem metadata from https://rubygems.org/.......
              2025-02-07T09:40:42.686846Z 01O Fetching rdoc 6.12.0
              2025-02-07T09:40:43.499990Z 01O Installing rdoc 6.12.0
              2025-02-07T09:40:43.102878Z 01E Cached checksum for rdoc-6.12.0 not found. Please (re-)generate Gemfile.checksum
              2025-02-07T09:40:43.102884Z 01E with `bundle exec bundler-checksum init`. See
              2025-02-07T09:40:43.102885Z 01E https://docs.gitlab.com/ee/development/gemfile.html#updating-the-checksum-file.
              2025-02-07T09:40:43.499813Z 00O section_end:1738921243:step_script
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gemfile_issues",
              pattern: "Cached checksum for .+ not found"
            })
          end
        end

        describe 'gems not found' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-07T15:01:48.950859Z 01O $ bundle exec gem list gitlab_quality-test_tooling
              2025-03-07T15:01:49.897207Z 01E bundler: failed to load command: gem (/usr/local/bin/gem)
              2025-03-07T15:01:49.898122Z 01E /usr/local/lib/ruby/site_ruby/3.3.0/bundler/definition.rb:676:in `materialize': Could not find rails-7.0.8.7, mutex_m-0.3.0, drb-2.2.1, bootsnap-1.18.4, ffi-1.17.1, gitlab-secret_detection-0.19.0 and many other gems in locally installed gems (Bundler::GemNotFound)
              2025-03-07T15:01:49.898276Z 01E 	from /usr/local/lib/ruby/site_ruby/3.3.0/bundler/definition.rb:232:in `specs'
              2025-03-07T15:01:49.898278Z 01E 	from /usr/local/lib/ruby/site_ruby/3.3.0/bundler/definition.rb:299:in `specs_for'
              2025-03-07T15:01:49.898280Z 01E 	from /usr/local/lib/ruby/site_ruby/3.3.0/bundler/runtime.rb:18:in `setup'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gems_not_found",
              pattern: "Bundler::GemNotFound"
            })
          end
        end

        describe 'failed to build gem native extension' do
          let(:trace_content) do
            <<~'TRACE'
              Installing unparser 0.6.10
              Fetching rspec 3.12.0
              Installing rspec 3.12.0
              Gem::Ext::BuildError: ERROR: Failed to build gem native extension.

              current directory:
              /builds/gitlab-org/gitlab/gems/gitlab-secret_detection/vendor/ruby/3.4.0/gems/google-protobuf-3.25.5/ext/google/protobuf_c
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gems_build",
              pattern: "Gem::Ext::BuildError: ERROR: Failed to build gem native extension."
            })
          end
        end

        describe 'checksum mismatch for bao-linux-amd64' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-10T13:33:32.944741Z 01O   For correct results you should run this as user git.
              2025-03-10T13:33:32.944742Z 01O
              2025-03-10T13:33:32.944743Z 01O Downloading binary `bao-linux-amd64` from https://gitlab.com/gitlab-org/govern/secrets-management/openbao-internal.git
              2025-03-10T13:33:32.944744Z 01O /builds/gitlab-org/gitlab/lib/gitlab/task_helpers.rb:199:in `block (2 levels) in download_package_file_version': RuntimeError: ERROR: Checksum mismatch for `bao-linux-amd64`: (Parallel::UndumpableException)
              2025-03-10T13:33:32.944746Z 01O   Expected: "865240e363a34d413c118ccd560ae1d29d6dad126da02a4fe36a2cdf6b19e29d"
              2025-03-10T13:33:32.944747Z 01O     Actual: "105cd936f54c1f14bfb7e8a758d6c5d9553f9fedddd9039d19e94f065dff5f5a"
              2025-03-10T13:33:32.944748Z 01O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "bao_linux_checksum_mismatch",
              pattern: "ERROR: Checksum mismatch for `bao-linux-amd64`"
            })
          end
        end

        describe 'cloning repository exit status 128' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T14:38:19.663540Z 01O
              2025-01-29T14:38:19.663541Z 01O == Seed from db/fixtures/development/12_snippets.rb
              2025-01-29T14:38:22.930791Z 01E rake aborted!
              2025-01-29T14:38:22.930796Z 01E Gitlab::Git::CommandError: 13:creating repository: cloning repository: exit status 128.
              2025-01-29T14:38:22.931751Z 01E /builds/gitlab-org/gitlab/lib/gitlab/git/wraps_gitaly_errors.rb:52:in `handle_default_error'
              2025-01-29T14:38:22.931755Z 01E /builds/gitlab-org/gitlab/lib/gitlab/git/wraps_gitaly_errors.rb:23:in `handle_error'
              2025-01-29T14:38:22.931792Z 01E /builds/gitlab-org/gitlab/lib/gitlab/git/wraps_gitaly_errors.rb:14:in `rescue in wrapped_gitaly_errors'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "cloning repository: exit status 128"
            })
          end
        end

        describe 'pathspec did not match any file known to git' do
          let(:trace_content) do
            <<~'TRACE'
              Updating files: 100% (82117/82117), done.   0% (2/82117)
              git_issues/8910083081.log-$ cd ${CI_JOB_NAME}
              git_issues/8910083081.log-$ for MERGE_INTO in "ruby3_3" "rails-next" # collapsed multi-line command
              git_issues/8910083081.log:error: pathspec 'ruby3_3' did not match any file(s) known to git
              Cleaning up project directory and file based variables
              ERROR: Job failed: exit code 1
              git_issues/8910083081.log-
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "did not match any file\\(s\\) known to git"
            })
          end
        end

        describe 'failed to push some refs' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-05T11:06:12.532126Z 01O $ git push -f "${FOSS_REPOSITORY}" "${AS_IF_FOSS_BRANCH}"
              2025-03-05T11:06:16.991456Z 01E To https://gitlab.com/gitlab-org/gitlab-foss.git
              2025-03-05T11:06:16.991461Z 01E  ! [remote rejected]     as-if-foss/bojan/swagger-fix -> as-if-foss/bojan/swagger-fix (unable to migrate objects to permanent storage)
              2025-03-05T11:06:16.991472Z 01E error: failed to push some refs to 'https://gitlab.com/gitlab-org/gitlab-foss.git'
              2025-03-05T11:06:17.477799Z 00O section_end:1741172777:step_script
              2025-03-05T11:06:17.477804Z 00O+section_start:1741172777:cleanup_file_variables
              2025-03-05T11:06:17.479504Z 00O+Cleaning up project directory and file based variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "as_if_foss_git_push_issues",
              pattern: "failed to push some refs to 'https://gitlab.com/gitlab-org/gitlab-foss.git'"
            })
          end
        end

        describe 'could not find remote ref' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-27T08:30:05.897520Z 01O Fetching changes with git depth set to 20...
              2025-02-27T08:30:05.102330Z 01O Initialized empty Git repository in /builds/gitlab-org/gitlab-foss/.git/
              2025-02-27T08:30:05.104698Z 01O Created fresh repository.
              2025-02-27T08:30:05.422999Z 01E fatal: couldn't find remote ref refs/heads/as-if-foss/pedropombeiro/504963/2-replace-ci_runner_machines-with-partitioned-table
              2025-02-27T08:30:05.545522Z 00O section_end:1740645005:get_sources
              2025-02-27T08:30:05.545527Z 00O+section_start:1740645005:clear_worktree
              2025-02-27T08:30:05.545588Z 00O+Deleting all tracked and untracked files due to source fetch failure
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "fatal: couldn't find remote ref"
            })
          end
        end

        describe 'expected flush after ref listing' do
          let(:trace_content) do
            <<~'TRACE'
              Setting up testing environment
              2025-03-06T11:08:18.100414Z 01O ==> Starting GitLab Elasticsearch Indexer (5.4.0) set up...
              2025-03-06T11:08:18.100415Z 01O error: RPC failed; HTTP 522 curl 22 The requested URL returned error: 522
              2025-03-06T11:08:18.100416Z 01O fatal: expected flush after ref listing
              2025-03-06T11:08:18.100416Z 01O ==> /builds/gitlab-org/gitlab/tmp/tests/gitlab-test set up in 39.033852713 seconds...
              2025-03-06T11:08:18.100417Z 01O fatal: cannot change to '/builds/gitlab-org/gitlab/tmp/tests/gitlab-test': No such file or directory
              2025-03-06T11:08:18.100418Z 01O fatal: cannot change to '/builds/gitlab-org/gitlab/tmp/tests/gitlab-test': No such file or directory
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "fatal: expected flush after ref listing"
            })
          end
        end

        describe 'fatal fetch-pack invalid index-pack output' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-22T20:32:39.636964Z 01E+Receiving objects:  65% (166710/256476), 160.47 MiB | 31.97 MiB/s
              2025-01-22T20:32:39.656649Z 01E+Receiving objects:  66% (169275/256476), 160.47 MiB | 31.97 MiB/s
              2025-01-22T20:32:39.714861Z 01E+fatal: early EOF
              2025-01-22T20:32:39.716066Z 01E fatal: fetch-pack: invalid index-pack output
              2025-01-22T20:32:40.397103Z 00O section_end:1737577960:get_sources
              2025-01-22T20:32:40.397113Z 00O+section_start:1737577960:upload_artifacts_on_failure
              2025-01-22T20:32:40.398778Z 00O+Uploading artifacts for failed job
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "fatal: fetch-pack: invalid index-pack output"
            })
          end
        end

        describe 'not a valid object name' do
          let(:trace_content) do
            <<~'TRACE'
              bundler: failed to load command: gitlab-housekeeper (/builds/gitlab-org/gitlab/gems/gitlab-housekeeper/vendor/ruby/3.2.0/bin/gitlab-housekeeper)
              /builds/gitlab-org/gitlab/gems/gitlab-housekeeper/lib/gitlab/housekeeper/shell.rb:23:in `execute': Failed with pid 92 exit 128 (Gitlab::Housekeeper::Shell::Error)

              fatal: not a valid object name: 'master'


                from /builds/gitlab-org/gitlab/gems/gitlab-housekeeper/lib/gitlab/housekeeper/git.rb:28:in `create_branch'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "fatal: Not a valid object name"
            })
          end
        end

        describe 'protocol error: bad pack header' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-27T14:58:24.834710Z 01O $ git fetch origin $CI_MERGE_REQUEST_TARGET_BRANCH_NAME:$CI_MERGE_REQUEST_TARGET_BRANCH_NAME --depth 20
              2025-02-27T14:58:24.715541Z 01E error: 53689 bytes of body are still expected
              2025-02-27T14:58:29.845315Z 01E fetch-pack: unexpected disconnect while reading sideband packet
              2025-02-27T14:58:29.845411Z 01E fatal: protocol error: bad pack header
              2025-02-27T14:58:30.717243Z 00O section_end:1740668310:step_script
              2025-02-27T14:58:30.717249Z 00O+section_start:1740668310:cleanup_file_variables
              2025-02-27T14:58:30.719730Z 00O+Cleaning up project directory and file based variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "fatal: protocol error: bad pack header"
            })
          end
        end

        describe 'the remote end hung up unexpectedly' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-25T09:53:24.476420Z 01E error: 26 bytes of body are still expected
              2025-02-25T09:53:24.508900Z 01E fatal: the remote end hung up unexpectedly
              2025-02-25T09:53:24.101302Z 01E bundler: failed to load command: danger (/builds/gitlab-org/gitlab/vendor/ruby/3.3.0/bin/danger)
              2025-02-25T09:53:24.101835Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/danger-9.4.2/lib/danger/scm_source/git_repo.rb:135:in `find_merge_base': Cannot find a merge base between danger_base and danger_head. If you are using shallow clone/fetch, try increasing the --depth (RuntimeError)
              2025-02-25T09:53:24.101841Z 01E 	from /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/danger-9.4.2/lib/danger/scm_source/git_repo.rb:18:in `diff_for_folder'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "git_issues",
              pattern: "fatal: the remote end hung up unexpectedly"
            })
          end
        end

        describe 'rubocop detected some offenses' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-15T09:41:53.694392Z 01O class QueueFixAndCreateComplianceStandardsAdherence < Gitlab::Database::Migration[2.2] ...
              2025-01-15T09:41:53.694394Z 01O ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
              2025-01-15T09:41:53.694395Z 01O
              2025-01-15T09:41:53.694396Z 01O 2 files inspected, 1 offense detected
              2025-01-15T09:41:42.147540Z 01E scripts/utils.sh: line 274: pop_var_context: head of shell_variables not a function context
              2025-01-15T09:41:53.945319Z 00O section_end:1736934113:step_script
              2025-01-15T09:41:53.945335Z 00O+section_start:1736934113:cleanup_file_variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rubocop",
              pattern: "offenses? detected"
            })
          end
        end

        describe 'filtered warnings' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-04T10:08:12.214315Z 01E There were warnings:
              2025-02-04T10:11:06.224133Z 01E ======================== Filtered warnings =====================================
              2025-02-04T10:11:06.224215Z 01E app/graphql/types/work_item_sort_enum.rb: GraphQL/Descriptions has the wrong namespace - replace it with Graphql/Descriptions
              2025-02-04T10:11:06.224216Z 01E app/graphql/types/work_items/widgets_sort_enum.rb: GraphQL/Descriptions has the wrong namespace - replace it with Graphql/Descriptions
              2025-02-04T10:11:06.224307Z 01E ======================= Unfiltered warnings ====================================
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rubocop",
              pattern: "=== Filtered warnings ==="
            })
          end
        end

        describe 'jest exited with status 1' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-28T23:51:53.600014Z 01E Snapshots:   0 total
              2025-02-28T23:51:53.600015Z 01E Time:        53.355 s
              2025-02-28T23:51:53.600016Z 01E Ran all test suites related to files matching /app\/assets\/javascripts\/diffs\/components\/app.vue|app\/assets\/javascripts\/diffs\/components\/compare_versions.vue|app\/assets\/javascripts\/diffs\/constants.js|app\/assets\/javascripts\/diffs\/store\/actions.js|app\/assets\/javascripts\/diffs\/store\/modules\/diff_state.js|app\/assets\/javascripts\/diffs\/store\/mutation_types.js|app\/assets\/javascripts\/diffs\/store\/mutations.js|app\/assets\/javascripts\/diffs\/stores\/file_browser.js|app\/assets\/javascripts\/diffs\/stores\/legacy_diffs\/actions.js|app\/assets\/javascripts\/diffs\/stores\/legacy_diffs\/index.js|app\/assets\/javascripts\/diffs\/stores\/legacy_diffs\/mutations.js|spec\/frontend\/diffs\/components\/app_spec.js|spec\/frontend\/diffs\/components\/compare_versions_spec.js|spec\/frontend\/diffs\/store\/actions_spec.js|spec\/frontend\/diffs\/store\/mutations_spec.js|spec\/frontend\/diffs\/stores\/file_browser_spec.js|spec\/frontend\/diffs\/stores\/legacy_diffs\/actions_spec.js|spec\/frontend\/diffs\/stores\/legacy_diffs\/mutations_spec.js/i.
              2025-02-28T23:51:53.873905Z 01E Command JEST_FIXTURE_JOBS_ONLY=1 VUE_VERSION=3 node_modules/.bin/jest --config jest.config.js --ci --shard=1/1 --logHeapUsage --testSequencer ./scripts/frontend/skip_specs_broken_in_vue_compat_fixture_ci_sequencer.js --passWithNoTests --findRelatedTests app/assets/javascripts/diffs/components/app.vue app/assets/javascripts/diffs/components/compare_versions.vue app/assets/javascripts/diffs/constants.js app/assets/javascripts/diffs/store/actions.js app/assets/javascripts/diffs/store/modules/diff_state.js app/assets/javascripts/diffs/store/mutation_types.js app/assets/javascripts/diffs/store/mutations.js app/assets/javascripts/diffs/stores/file_browser.js app/assets/javascripts/diffs/stores/legacy_diffs/actions.js app/assets/javascripts/diffs/stores/legacy_diffs/index.js app/assets/javascripts/diffs/stores/legacy_diffs/mutations.js spec/frontend/diffs/components/app_spec.js spec/frontend/diffs/components/compare_versions_spec.js spec/frontend/diffs/store/actions_spec.js spec/frontend/diffs/store/mutations_spec.js spec/frontend/diffs/stores/file_browser_spec.js spec/frontend/diffs/stores/legacy_diffs/actions_spec.js spec/frontend/diffs/stores/legacy_diffs/mutations_spec.js exited with status 1
              2025-02-28T23:51:53.874133Z 01E#{'  '}
              2025-02-28T23:51:53.874682Z 01E Having trouble getting tests to pass under Vue 3? These resources may help:
              2025-02-28T23:51:53.874686Z 01E#{'  '}
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "jest",
              pattern: "Command .+ node_modules/.bin/jest.+ exited with status 1"
            })
          end
        end

        describe 'methods have no test coverage' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-24T20:19:37.262324Z 01E /usr/local/bin/ruby: warning: Ruby was built without YJIT support. You may need to install rustc to build Ruby with YJIT.
              2025-02-24T20:19:37.408335Z 01E /usr/local/bin/ruby: warning: Ruby was built without YJIT support. You may need to install rustc to build Ruby with YJIT.
              2025-02-24T20:19:50.470350Z 01O 🚨 WARNING: Coverage data is older than your latest changes and results might be incomplete. Re-run tests to update
              2025-02-24T20:19:50.470500Z 01O undercover: 👮‍♂️ some methods have no test coverage! Please add specs for methods listed below
              2025-02-24T20:19:50.470530Z 01O 🚨 1) node `requirement_included_in_base_access_level?` type: instance method,
              2025-02-24T20:19:50.470560Z 01O       loc: ee/app/models/members/member_role.rb:216:231, coverage: 87.5%
              2025-02-24T20:19:50.470570Z 01O 216:   def requirement_included_in_base_access_level?(requirement) hits: n/a
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rspec_undercoverage",
              pattern: "some methods have no test coverage!"
            })
          end
        end

        describe 'gitaly did not boot properly' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-30T02:14:12.513935Z 01O vue-loader-vue3@17.4.2 ✔
              Done in 1.20s.

              2025-01-30T02:14:12.549153Z 01O gitaly spawn failed
              2025-01-30T02:14:11.221310Z 01E
              2025-01-30T02:14:12.767622Z 00O section_end:1738203252:step_script
              2025-01-30T02:14:12.767626Z 00O+section_start:1738203252:upload_artifacts_on_failure
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "gitaly_spawn_failed",
              pattern: "gitaly spawn failed"
            })
          end
        end

        describe 'Apollo was loading' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-06T10:32:50.512282Z 01E Geo DB won't be set up.
              2025-03-06T10:32:50.512286Z 01E Embedding DB won't be set up.
              2025-03-06T10:32:50.524131Z 01O $ apollo client:download-schema --config=config/apollo.config.js ${GRAPHQL_SCHEMA_APOLLO_FILE}
              2025-03-06T10:32:53.435457Z 01O Loading Apollo Project [started]
              2025-03-06T10:32:53.437463Z 01O Loading Apollo Project [completed]
              2025-03-06T10:32:53.437916Z 01O Saving schema to tmp/tests/graphql/gitlab_schema_apollo.graphql [started]
              2025-03-06T10:32:53.526426Z 01O Saving schema to tmp/tests/graphql/gitlab_schema_apollo.graphql [completed]
              2025-03-06T10:32:50.513953Z 01E
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "apollo",
              pattern: "Loading Apollo Project"
            })
          end
        end

        describe 'job failed exit code 112' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-23T13:16:15.986266Z 00O+Cleaning up project directory and file based variables
              2025-01-23T13:16:16.524187Z 00O section_end:1737638176:cleanup_file_variables
              2025-01-23T13:16:16.524193Z 00O+
              2025-01-23T13:16:23.991565Z 00O ERROR: Job failed: exit code 112
              2025-01-23T13:16:23.991567Z 00O
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rspec_test_already_failed_on_default_branch",
              pattern: "ERROR: Job failed: exit code 112"
            })
          end
        end

        describe 'unable to compile webpack production bundle' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-06T13:08:37.847742Z 01O I, [2025-03-06T13:07:34.790074 #614]  INFO -- : Writing /builds/gitlab-org/gitlab/public/assets/express/lib/application-d5e505014773a6c7499f2a5e7a54f057b290edb75c0eabb6187a799d70912d5a.js.gz
              2025-03-06T13:08:37.847743Z 01O `rake:assets:precompile` finished in 79.699070787 seconds
              2025-03-06T13:08:37.847744Z 01O Compiling frontend assets with webpack, running: yarn webpack > tmp/webpack-output.log 2>&1
              2025-03-06T13:08:37.847744Z 01O Error: Unable to compile webpack production bundle.
              2025-03-06T13:08:37.847745Z 01O Last 100 line of webpack log:
              2025-03-06T13:08:37.847746Z 01O     at /builds/gitlab-org/gitlab/node_modules/webpack/lib/NormalModuleFactory.js:130:21
              2025-03-06T13:08:37.847746Z 01O     at /builds/gitlab-org/gitlab/node_modules/webpack/lib/NormalModuleFactory.js:224:22
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "assets_compilation",
              pattern: "Error: Unable to compile webpack production bundle"
            })
          end
        end

        describe 'VueJS3 - expected unset ENV var' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-31T02:23:01.109407Z 01O $ run_timed_command "scripts/frontend/jest_ci.js --vue3"
              2025-01-31T02:23:01.111237Z 01E $ scripts/frontend/jest_ci.js --vue3
              2025-01-31T02:23:01.111366Z 01E Expected unset environment variable VUE_VERSION, or VUE_VERSION=2, got VUE_VERSION="3".
              2025-01-31T02:23:01.213928Z 01E /usr/bin/bash: line 325: pop_var_context: head of shell_variables not a function context
              2025-01-31T02:23:01.583515Z 00O section_end:1738290181:step_script
              2025-01-31T02:23:01.583520Z 00O+section_start:1738290181:upload_artifacts_on_failure
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "vuejs3",
              pattern: "Expected unset environment variable"
            })
          end
        end

        describe 'now pass under vue 3' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-18T09:51:27.909327Z 01E (Use `node --trace-warnings ...` to show where the warning was created)
              2025-02-18T09:51:27.909328Z 01E (node:82) [DEP0137] DeprecationWarning: Closing a FileHandle object on garbage collection is deprecated. Please close FileHandle objects explicitly using FileHandle.prototype.close(). In the future, an error will be thrown if a file descriptor is closed during garbage collection.
              2025-02-18T09:51:27.910363Z 01E#{'  '}
              2025-02-18T09:51:27.910534Z 01E The following 2 spec files either now pass under Vue 3, or no longer exist, and so must be removed from quarantine:
              2025-02-18T09:51:27.910716Z 01E#{'  '}
              2025-02-18T09:51:27.910720Z 01E spec/frontend/issues/show/components/incidents/create_timeline_events_form_spec.js
              2025-02-18T09:51:27.910721Z 01E spec/frontend/issues/show/components/incidents/edit_timeline_event_spec.js
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "vuejs3",
              pattern: "either now pass under Vue 3, or no longer exist"
            })
          end
        end

        describe 'use of doubles or partial doubles' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T17:45:41.668384Z 01O
              2025-01-29T17:45:41.668386Z 01O Randomized with seed 47202
              2025-01-29T17:45:41.668387Z 01O
              2025-01-29T17:45:41.887266Z 01E /builds/gitlab-org/gitlab-foss/vendor/ruby/3.3.0/gems/rspec-mocks-3.13.2/lib/rspec/mocks/space.rb:51:in `raise_lifecycle_message': The use of doubles or partial doubles from rspec-mocks outside of the per-test lifecycle is not supported. (RSpec::Mocks::OutsideOfExampleError)
              2025-01-29T17:45:41.887271Z 01E 	from /builds/gitlab-org/gitlab-foss/vendor/ruby/3.3.0/gems/rspec-mocks-3.13.2/lib/rspec/mocks/space.rb:11:in `proxy_for'
              2025-01-29T17:45:41.887272Z 01E 	from /builds/gitlab-org/gitlab-foss/vendor/ruby/3.3.0/gems/rspec-mocks-3.13.2/lib/rspec/mocks/test_double.rb:112:in `__mock_proxy'
              2025-01-29T17:45:41.887274Z 01E 	from /builds/gitlab-org/gitlab-foss/vendor/ruby/3.3.0/gems/rspec-mocks-3.13.2/lib/rspec/mocks/test_double.rb:29:in `null_object?'
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "rspec_usage",
              pattern: "The use of doubles or partial doubles from rspec-mocks " \
                "outside of the per-test lifecycle is not supported."
            })
          end
        end

        describe 'multi-line patterns' do
          describe 'valid RSpec error or flaky test (expected/got)' do
            describe 'first case' do
              let(:trace_content) do
                <<~'TRACE'
                  2025-01-16T18:24:55.112039Z 01O Failed examples:
                  2025-01-16T18:24:55.112040Z 01O
                  2025-01-16T18:24:55.112041Z 01O rspec ./qa/specs/features/ee/browser_ui/13_secure/enable_advanced_sast_spec.rb:50 # Secure when Advanced SAST is enabled finds a vulnerability
                  2025-01-16T18:24:55.111929Z 01O   2) Package Maven project level endpoint using a ci job token pushes and pulls a maven package via maven
                  2025-01-16T18:24:55.111930Z 01O      Failure/Error: expect(job).to be_successful(timeout: 800)
                  2025-01-16T18:24:55.111932Z 01O        expected `QA::Page::Project::Job::Show.successful?({:timeout=>800})` to be truthy, got false
                TRACE
              end

              it 'returns the correct category' do
                expect(parser.process(trace_path)).to eq({
                  failure_category: "rspec_valid_rspec_errors_or_flaky_tests",
                  pattern: "Failed examples:,expected( :| #| \\[ | \\`)"
                })
              end
            end

            describe 'second case' do
              let(:trace_content) do
                <<~'TRACE'
                  2025-01-16T18:24:55.112039Z 01O Failed examples:
                  2025-02-27T00:24:19.687886Z 01O
                  2025-02-27T00:24:19.687886Z 01O      3.2) Failure/Error: expect(response).to include_pagination_headers
                  2025-02-27T00:24:19.687887Z 01O             expected #<ActionDispatch::TestResponse:0x00007b3c9f890c90 @mon_data=#<Monitor:0x00007b3ca73559f8>, @mon_data_..._token=glpat-[MASKED]&topic=ruby%2C+javascript" for 127.0.0.1>> to include pagination headers
                  2025-02-27T00:24:19.687895Z 01O           # ./spec/requests/api/projects_spec.rb:354:in `block (5 levels) in <main>'
                TRACE
              end

              it 'returns the correct category' do
                expect(parser.process(trace_path)).to eq({
                  failure_category: "rspec_valid_rspec_errors_or_flaky_tests",
                  pattern: "Failed examples:,expected( :| #| \\[ | \\`)"
                })
              end
            end

            describe 'third case' do
              let(:trace_content) do
                <<~'TRACE'
                  2025-01-16T18:24:55.112039Z 01O Failed examples:
                  2025-01-16T18:24:55.112040Z 01O
                  2025-02-19T06:26:04.189142Z 01O   11) profiles/accounts/show for account deletion when user has sole ownership of a organization when feature flag ui_for_organizations is false does not render organization as a link in the list
                  2025-02-19T06:26:04.189143Z 01O       Failure/Error: - add_page_specific_style 'page_bundles/profile'
                  2025-02-19T06:26:04.189144Z 01O
                  2025-02-19T06:26:04.189145Z 01O       ActionView::Template::Error:
                  2025-02-19T06:26:04.189146Z 01O         Expected :on_tstring_end but got: on_tstring_content
                  2025-02-19T06:26:04.189146Z 01O       # ./app/views/profiles/accounts/show.html.haml:1:in `_app_views_profiles_accounts_show_html_haml___4173042797379344905_576860'
                TRACE
              end

              it 'returns the correct category' do
                expect(parser.process(trace_path)).to eq({
                  failure_category: "rspec_valid_rspec_errors_or_flaky_tests",
                  pattern: "Failed examples:,expected( :| #| \\[ | \\`)"
                })
              end
            end
          end

          describe 'valid RSpec error or flaky test (generic)' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-16T18:24:55.112039Z 01O Failed examples:
                2025-01-16T18:24:55.112040Z 01O
                2025-01-16T18:24:55.112041Z 01O rspec ./qa/specs/features/ee/browser_ui/13_secure/enable_advanced_sast_spec.rb:50 # Secure when Advanced SAST is enabled finds a vulnerability
                [...]
                2025-02-28T01:22:19.260147Z 01O       # ./spec/services/ci/pipeline_processing/atomic_processing_service_spec.rb:10:in `block (3 levels) in <main>'
                2025-02-28T01:22:19.260148Z 01O
                2025-02-28T01:22:19.260149Z 01O   28) Ci::PipelineProcessing::AtomicProcessingService Pipeline Processing Service Tests With Yaml test_file_path: "/builds/gitlab-org/gitlab-foss/spec/services/ci/pipeline_processing/test_cases/dag_same_stages.yml" follows transitions
                2025-02-28T01:22:19.260154Z 01O       Failure/Error: existing_members = source.members_and_requesters.with_user(users + users_by_emails.values).index_by(&:user_id)
                2025-02-28T01:22:19.260155Z 01O
                2025-02-28T01:22:19.260156Z 01O       NoMethodError:
                2025-02-28T01:22:19.260156Z 01O         undefined method `members_and_requesters' for an instance of Project
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "rspec_valid_rspec_errors_or_flaky_tests",
                pattern: "Failed examples:,Failure/Error:"
              })
            end
          end

          describe 'Jest (exit code 1)' do
            let(:trace_content) do
              <<~'TRACE'
                2025-03-08T01:19:13.661325Z 01E Time:        142.969 s
                2025-03-08T01:19:13.661326Z 01E Ran all test suites.
                2025-03-08T01:19:13.675070Z 01E Test results written to: jest-test-report.json
                error Command failed with exit code 1.
                info Visit https://yarnpkg.com/en/docs/cli/run for documentation about this command.
                2025-03-08T01:19:14.286000Z 01O Proceed to parsing test report...
                2025-03-08T01:19:14.461695Z 01O  ============= snapshot test report start ==============
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "jest",
                pattern: "Ran all test suites,Command failed with exit code 1"
              })
            end
          end

          describe 'Jest (exit code 1 variant)' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-13T11:50:08.204186Z 01E Snapshots:   0 total
                2025-02-13T11:50:08.204188Z 01E Time:        9.814 s
                2025-02-13T11:50:08.204188Z 01E Ran all test suites related to files matching /app\/assets\/javascripts\/performance_bar\/components\/add_request.vue|app\/assets\/javascripts\/performance_bar\/components\/detailed_metric.vue|app\/assets\/javascripts\/performance_bar\/components\/info_modal\/info_app.vue|app\/assets\/javascripts\/performance_bar\/components\/performance_bar_app.vue|app\/assets\/javascripts\/performance_bar\/components\/request_selector.vue|app\/assets\/stylesheets\/framework\/variables.scss|app\/assets\/stylesheets\/performance_bar.scss/i.
                2025-02-13T11:50:08.358800Z 01E Command JEST_FIXTURE_JOBS_ONLY= VUE_VERSION= node_modules/.bin/jest --config jest.config.js --ci --shard=1/4 --logHeapUsage --testSequencer ./scripts/frontend/fixture_ci_sequencer.js --passWithNoTests --findRelatedTests app/assets/javascripts/performance_bar/components/add_request.vue app/assets/javascripts/performance_bar/components/detailed_metric.vue app/assets/javascripts/performance_bar/components/info_modal/info_app.vue app/assets/javascripts/performance_bar/components/performance_bar_app.vue app/assets/javascripts/performance_bar/components/request_selector.vue app/assets/stylesheets/framework/variables.scss app/assets/stylesheets/performance_bar.scss exited with status 1
                2025-02-13T11:50:08.363973Z 01E /usr/bin/bash: line 325: pop_var_context: head of shell_variables not a function context
                2025-02-13T11:50:08.831654Z 00O section_end:1739447408:step_script
                2025-02-13T11:50:08.831660Z 00O+section_start:1739447408:upload_artifacts_on_failure
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "jest",
                pattern: "Command .+ node_modules/.bin/jest.+ exited with status 1"
              })
            end
          end

          describe 'danger errors' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-14T14:16:25.856780Z 01O $ if [ -z "${DANGER_GITLAB_API_TOKEN}" ]; then # collapsed multi-line command
                [...]
                2025-03-03T23:20:42.194656Z 01O Importing rule z_retry_link at /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/gitlab-dangerfiles-4.8.1/lib/danger/rules/z_retry_link
                2025-03-03T23:20:42.194658Z 01O Results:
                2025-03-03T23:20:42.194659Z 01O
                2025-03-03T23:20:42.194660Z 01O Errors:
                2025-03-03T23:20:42.194661Z 01O - [ ] d4ac7d497c6bc4f56ca8408b95203c27862c7785: The commit subject may not be longer than 72 characters. For more information, take a look at our [Commit message guidelines](https://docs.gitlab.com/ee/development/contributing/merge_request_workflow.html#commit-messages-guidelines).
                2025-03-03T23:20:42.194664Z 01O - [ ] The [database migration pipeline](https://docs.gitlab.com/development/database/database_migration_pipeline/)
                2025-03-03T23:20:42.194666Z 01O must be triggered by the job `db:gitlabcom-database-testing` must be run before requesting
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "danger",
                pattern: "DANGER_GITLAB_API_TOKEN,Errors:"
              })
            end
          end
        end

        describe 'catchall patterns' do
          describe 'Ruby crash info' do
            let(:trace_content) do
              <<~'TRACE'
                2025-03-03T09:01:41.695302Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/actionpack-7.0.8.7/lib/action_dispatch/routing/mapper.rb:155: [BUG] try to mark T_NONE object
                2025-03-03T09:01:41.695311Z 01E ruby 3.3.7 (2025-01-15 revision be31f993d7) +YJIT [x86_64-linux]
                2025-03-03T09:01:41.695313Z 01E
                2025-03-03T09:01:41.695314Z 01E -- Control frame information -----------------------------------------------
                2025-03-03T09:01:41.695316Z 01E c:0134 p:---- s:0776 e:000775 CFUNC  :merge
                2025-03-03T09:01:41.695317Z 01E c:0133 p:0268 s:0771 e:000770 METHOD /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/actionpack-7.0.8.7/lib/action_dispatch/routing/mapper.rb:155 [FINISH]
                2025-03-03T09:01:41.695320Z 01E c:0132 p:---- s:0750 e:000749 CFUNC  :new
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_crash_core_dump",
                pattern: "Control frame information"
              })
            end
          end

          describe 'openssl ssl error' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-28T04:57:39.345741Z 01E 	from /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/bundler-2.5.11/exe/bundle:20:in `<top (required)>'
                2025-02-28T04:57:39.345742Z 01E 	from /usr/local/bin/bundle:25:in `load'
                2025-02-28T04:57:39.345743Z 01E 	from /usr/local/bin/bundle:25:in `<main>'
                2025-02-28T04:57:39.345743Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/net-protocol-0.1.3/lib/net/protocol.rb:46:in `connect_nonblock': SSL_connect returned=1 errno=0 peeraddr=35.185.44.232:443 state=error: unexpected eof while reading (OpenSSL::SSL::SSLError)
                2025-02-28T04:57:39.345749Z 01E 	from /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/net-protocol-0.1.3/lib/net/protocol.rb:46:in `ssl_socket_connect'
                2025-02-28T04:57:39.345750Z 01E 	from /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/net-http-0.6.0/lib/net/http.rb:1742:in `connect'
                2025-02-28T04:57:39.345751Z 01E 	from /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/net-http-0.6.0/lib/net/http.rb:1642:in `do_start'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_openssl",
                pattern: "OpenSSL::SSL::SSLError"
              })
            end
          end

          describe 'load error' do
            let(:trace_content) do
              <<~'TRACE'

                Failure/Error: require 'httparty'

                LoadError:
                  cannot load such file -- csv
                # ./vendor/ruby/3.4.0/gems/httparty-0.21.0/lib/httparty.rb:10:in '<top (required)>'
                # ./lib/gitlab/housekeeper/gitlab_client.rb:3:in '<top (required)>'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_could_not_load_file",
                pattern: "LoadError:"
              })
            end
          end

          describe 'job timeouts' do
            let(:trace_content) do
              <<~'TRACE'
                PASS  ee/spec/frontend/contribution_events/components/contribution_event/contribution_event_reopened_spec.js (1328 MB heap size)
                PASS  spec/frontend/contribution_events/components/contribution_event/contribution_event_updated_spec.js (1359 MB heap size)
                WARNING: step_script could not run to completion because the timeout was exceeded. For more control over job and script timeouts see: https://docs.gitlab.com/ee/ci/runners/configure_runners.html#set-script-and-after_script-timeouts
                ERROR: Job failed: execution took longer than 1h30m0s seconds
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "job_timeouts",
                pattern: "execution took longer than 1h30m0s seconds"
              })
            end
          end

          describe 'job canceled' do
            let(:trace_content) do
              <<~'TRACE'
                Running command: bundle exec rspec -Ispec -rspec_helper --color --failure-exit-code 1 --error-exit-code 2 --format documentation --format Support::Formatters::JsonFormatter --out rspec/rspec-9038271152.json --format RspecJunitFormatter --out rspec/rspec-9038271152.xml --fail-fast=20 --tag ~quarantine --tag ~level:background_migration --tag ~click_house --tag ~real_ai_request -- spec/models/deployment_spec.rb
                Terminated
                WARNING: after_script failed, but job will continue unaffected: context canceled
                ERROR: Job failed: canceled
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "unknown_failure_canceled",
                pattern: "ERROR: Job failed: canceled"
              })
            end
          end

          describe 'Ruby - Could not load a file' do
            let(:trace_content) do
              <<~'TRACE'
                Failure/Error: require 'httparty'

                OtherError:
                  cannot load such file -- csv
                # ./vendor/ruby/3.4.0/gems/httparty-0.21.0/lib/httparty.rb:10:in '<top (required)>'
                # ./lib/gitlab/housekeeper/gitlab_client.rb:3:in '<top (required)>'
                # ./lib/gitlab/housekeeper/runner.rb:9:in '<top (required)>'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_could_not_load_file",
                pattern: "cannot load such file"
              })
            end
          end

          describe 'undefined local variable or method' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-31T22:05:19.120810Z 01O [Jan 31 2025 22:05:19 UTC (Gitlab QA)] INFO  -- Shell command: `docker login --username "gitlab-ci-token" --password "*****" registry.gitlab.com`
                2025-01-31T22:05:19.364190Z 01O [Jan 31 2025 22:05:19 UTC (Gitlab QA)] INFO  -- Shell command: `docker pull -q registry.gitlab.com/gitlab-org/build/omnibus-gitlab-mirror/gitlab-ee:e5d0f03447f7867b12e00be60c8e5c3c23208046-ruby3.2.5`
                2025-01-31T22:05:19.620056Z 01E #<Thread:0x00007fb2b71bdb10 /builds/gitlab-org/gitlab/.gems/gems/gitlab-qa-15.2.0/lib/gitlab/qa/component/gitaly_cluster.rb:70 run> terminated with exception (report_on_exception is true):
                2025-01-31T22:05:19.624926Z 01E /builds/gitlab-org/gitlab/.gems/gems/gitlab-qa-15.2.0/lib/gitlab/qa/component/base.rb:203:in `rescue in instance_no_teardown': undefined local variable or method `get_reconfigure_log_file_from_artefact' for #<Gitlab::QA::Component::Gitaly:0x00007fb2b6e7cc80> (NameError)
                2025-01-31T22:05:19.624930Z 01E#{' '}
                2025-01-31T22:05:19.624931Z 01E             reconfigure_log_file = get_reconfigure_log_file_from_artefact
                2025-01-31T22:05:19.624933Z 01E                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_undefined_method_or_variable",
                pattern: "undefined local variable or method `"
              })
            end
          end

          describe 'undefined method' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-24T08:43:18.847842Z 01O GRANT
                2025-01-24T08:43:17.795630Z 01E $ bundle exec rake db:drop db:create db:schema:load db:migrate gitlab:db:lock_writes
                2025-01-24T08:43:18.861812Z 01E rake aborted!
                2025-01-24T08:43:37.606449Z 01E NoMethodError: undefined method `primary_key' for module ActiveRecord::Encryption
                2025-01-24T08:43:37.607136Z 01E /builds/gitlab-org/gitlab/lib/gitlab/database/encryption/key_provider_service.rb:28:in `<class:KeyProviderService>'
                2025-01-24T08:43:37.607139Z 01E /builds/gitlab-org/gitlab/lib/gitlab/database/encryption/key_provider_service.rb:6:in `<module:Encryption>'
                2025-01-24T08:43:37.607140Z 01E /builds/gitlab-org/gitlab/lib/gitlab/database/encryption/key_provider_service.rb:5:in `<module:Database>'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_undefined_method_or_variable",
                pattern: "undefined method `"
              })
            end
          end

          describe 'frozen error' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-17T00:29:54.636329Z 01O An error occurred while loading ./spec/services/groups/transfer_service_spec.rb.
                2025-01-17T00:29:54.636330Z 01O Failure/Error: require_relative '../config/environment'
                2025-01-17T00:29:54.636332Z 01O#{' '}
                2025-01-17T00:29:54.636333Z 01O FrozenError:
                2025-01-17T00:29:54.636333Z 01O   can't modify frozen Array: ["/builds/gitlab-org/gitlab-foss/app/channels", "/builds/gitlab-org/gitlab-foss/app/components", "/builds/gitlab-org/gitlab-foss/app/controllers", "/builds/gitlab-org/gitlab-foss/app/controllers/concerns", "/builds/gitlab-org/gitlab-foss/app/enums", "/builds/gitlab-org/gitlab-foss/app/events", "/builds/gitlab-org/gitlab-foss/app/experiments", "/builds/gitlab-org/gitlab-foss/app/facades", "/builds/gitlab-org/gitlab-foss/app/finders", "/builds/gitlab-org/gitlab-foss/app/finders/concerns", "/builds/gitlab-org/gitlab-foss/app/graphql", "/builds/gitlab-org/gitlab-foss/app/helpers", "/builds/gitlab-org/gitlab-foss/app/mailers", "/builds/gitlab-org/gitlab-foss/app/models", "/builds/gitlab-org/gitlab-foss/app/models/concerns", "/builds/gitlab-org/gitlab-foss/app/policies", "/builds/gitlab-org/gitlab-foss/app/policies/concerns", "/builds/gitlab-org/gitlab-foss/app/presenters", "/builds/gitlab-org/gitlab-foss/app/serializers", "/builds/gitlab-org/gitlab-foss/app/serializers/concerns", "/builds/gitlab-org/gitlab-foss/app/services", "/builds/gitlab-org/gitlab-foss/app/services/concerns", "/builds/gitlab-org/gitlab-foss/app/uploaders", "/builds/gitlab-org/gitlab-foss/app/validators", "/builds/gitlab-org/gitlab-foss/app/workers", "/builds/gitlab-org/gitlab-foss/app/workers/concerns", "/builds/gitlab-org/gitlab-foss/lib", "/builds/gitlab-org/gitlab-foss/app/models/badges", "/builds/gitlab-org/gitlab-foss/app/models/hooks", "/builds/gitlab-org/gitlab-foss/app/models/members", "/builds/gitlab-org/gitlab-foss/app/graphql/resolvers/concerns", "/builds/gitlab-org/gitlab-foss/app/graphql/mutations/concerns", "/builds/gitlab-org/gitlab-foss/app/graphql/types/concerns", "/builds/gitlab-org/gitlab-foss/lib/generators", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/peek-1.1.0/app/controllers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/sentry-rails-5.22.1/app/jobs", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/doorkeeper-device_authorization_grant-1.0.3/app/controllers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/doorkeeper-openid_connect-1.8.10/app/controllers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/doorkeeper-openid_connect-1.8.10/app/controllers/concerns", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/doorkeeper-5.8.1/app/controllers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/doorkeeper-5.8.1/app/helpers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/devise-4.9.3/app/controllers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/devise-4.9.3/app/helpers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/devise-4.9.3/app/mailers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/view_component-3.21.0/app/controllers", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/view_component-3.21.0/app/controllers/concerns", "/builds/gitlab-org/gitlab-foss/vendor/ruby/3.2.0/gems/view_component-3.21.0/app/helpers"]
                2025-01-17T00:29:54.636372Z 01O # ./vendor/ruby/3.2.0/gems/railties-7.0.8.7/lib/rails/engine.rb:574:in `unshift'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_frozen",
                pattern: "FrozenError:"
              })
            end
          end

          describe 'wrong argument type' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-27T20:47:11.500677Z 01E Instance method "run!" is already defined in Object, use generic helper instead or set StateMachines::Machine.ignore_method_conflicts = true.
                2025-01-27T20:47:21.481720Z 01E Instance method "run!" is already defined in Object, use generic helper instead or set StateMachines::Machine.ignore_method_conflicts = true.
                2025-01-27T20:47:29.966588Z 01E bundler: failed to load command: derailed (/builds/gitlab-org/gitlab/vendor/ruby/3.3.0/bin/derailed)
                2025-01-27T20:47:29.968454Z 01E /builds/gitlab-org/gitlab/ee/lib/dast_variables.rb:5:in `extend': wrong argument type Class (expected Module) (TypeError)
                2025-01-27T20:47:29.968459Z 01E#{' '}
                2025-01-27T20:47:29.968460Z 01E     extend self
                2025-01-27T20:47:29.968461Z 01E            ^^^^
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_wrong_argument_type",
                pattern: "wrong argument type.+expected.+"
              })
            end
          end

          describe 'uninitialized constant' do
            let(:trace_content) do
              <<~'TRACE'
                2025-03-04T19:57:42.783225Z 01O $ bundle exec rake gitlab:db:dictionary:generate
                2025-03-04T19:57:41.910953Z 01E rake aborted!
                2025-03-04T19:58:26.845153Z 01E NameError: uninitialized constant Gitlab::PDF
                2025-03-04T19:58:26.845310Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/zeitwerk-2.6.7/lib/zeitwerk/loader/helpers.rb:135:in `const_get'
                2025-03-04T19:58:26.845312Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/zeitwerk-2.6.7/lib/zeitwerk/loader/helpers.rb:135:in `cget'
                2025-03-04T19:58:26.845314Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/zeitwerk-2.6.7/lib/zeitwerk/loader/eager_load.rb:176:in `block in actual_eager_load_dir'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_uninitialized_constant",
                pattern: "uninitialized constant "
              })
            end
          end

          describe 'gitlab settings missing setting' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-17T17:17:28.278932Z 01O GRANT
                2025-02-17T17:17:27.781743Z 01E $ bundle exec rake db:drop db:create db:schema:load db:migrate gitlab:db:lock_writes
                2025-02-17T17:17:28.283143Z 01E rake aborted!
                2025-02-17T17:17:51.132055Z 01E GitlabSettings::MissingSetting: option 'id' not defined
                2025-02-17T17:17:51.132703Z 01E /builds/gitlab-org/gitlab-foss/lib/gitlab_settings/options.rb:163:in `method_missing'
                2025-02-17T17:17:51.132706Z 01E /builds/gitlab-org/gitlab-foss/config/initializers/session_store.rb:21:in `<main>'
                2025-02-17T17:17:51.132708Z 01E /builds/gitlab-org/gitlab-foss/vendor/ruby/3.3.0/gems/railties-7.0.8.7/lib/rails/engine.rb:667:in `load'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_gitlab_settings_missing_setting",
                pattern: "GitlabSettings::MissingSetting"
              })
            end
          end

          describe 'syntax error unexpected' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-16T19:24:17.851518Z 01O Created database 'gitlabhq_test'
                2025-02-16T19:24:17.891070Z 01O Created database 'gitlabhq_test_ci'
                2025-02-16T19:23:43.400231Z 01E rake aborted!
                2025-02-16T19:24:40.382175Z 01E SyntaxError: /builds/gitlab-org/gitlab/db/migrate/20241211134706_add_snippet_project_id_to_snippet_repositories.rb:4: syntax error, unexpected ':', expecting `end' or dummy end
                2025-02-16T19:24:40.382180Z 01E milestone: '17.10'
                2025-02-16T19:24:40.382182Z 01E          ^
                2025-02-16T19:24:40.382183Z 01E /builds/gitlab-org/gitlab/vendor/ruby/3.3.0/gems/bootsnap-1.18.4/lib/bootsnap/load_path_cache/core_ext/kernel_require.rb:30:in `require'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_syntax",
                pattern: "syntax error, unexpected"
              })
            end
          end

          describe 'eof error' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-30T23:37:56.404290Z 01E+  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
                2025-01-30T23:37:56.650334Z 01E+100 29778  100 29778    0     0   115k      0 --:--:-- --:--:-- --:--:--  115k
                2025-01-30T23:37:56.653294Z 01O $ # $FIND_CHANGES_MERGE_REQUEST_IID is defined in as-if-foss.gitlab-ci.yml # collapsed multi-line command
                2025-01-30T23:37:58.296158Z 01E /usr/local/lib/ruby/3.3.0/net/protocol.rb:237:in `rbuf_fill': end of file reached (EOFError)
                2025-01-30T23:37:58.296168Z 01E 	from /usr/local/lib/ruby/3.3.0/net/protocol.rb:199:in `readuntil'
                2025-01-30T23:37:58.296169Z 01E 	from /usr/local/lib/ruby/3.3.0/net/protocol.rb:209:in `readline'
                2025-01-30T23:37:58.296171Z 01E 	from /usr/local/bundle/gems/net-http-0.6.0/lib/net/http/response.rb:625:in `read_chunked'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_eof",
                pattern: "EOFError"
              })
            end
          end

          describe 'type error' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-06T13:01:33.343632Z 01O An error occurred while loading spec_helper.
                2025-02-06T13:01:33.343634Z 01O Failure/Error: require_relative '../config/environment'
                2025-02-06T13:01:33.343635Z 01O#{' '}
                2025-02-06T13:01:33.343635Z 01O TypeError:
                2025-02-06T13:01:33.343636Z 01O   CustomFields is not a module
                2025-02-06T13:01:33.343637Z 01O   /builds/gitlab-org/gitlab/ee/app/models/work_items/widgets/custom_fields.rb:5: previous definition of CustomFields was here
                2025-02-06T13:01:33.343638Z 01O # ./ee/app/services/work_items/widgets/custom_fields/update_service.rb:5:in `<module:Widgets>'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_type",
                pattern: "TypeError:"
              })
            end
          end

          describe 'runtime error' do
            let(:trace_content) do
              <<~'TRACE'
                2025-03-06T10:44:53.974564Z 01O Downloading binary `bao-linux-amd64` from https://gitlab.com/gitlab-org/govern/secrets-management/openbao-internal.git
                2025-03-06T10:44:53.974565Z 01O OpenBao binary already built. Skip building...
                2025-03-06T10:44:53.974566Z 01O ==> OpenBao set up in 2.194574012 seconds...
                2025-03-06T10:44:53.974567Z 01O /builds/gitlab-org/gitlab/spec/support/helpers/test_env.rb:336:in `setup_repo': Could not fetch test seed repository. (RuntimeError)
                2025-03-06T10:44:53.974568Z 01O 	from /builds/gitlab-org/gitlab/spec/support/helpers/test_env.rb:316:in `setup_forked_repo'
                2025-03-06T10:44:53.974568Z 01O 	from /builds/gitlab-org/gitlab/spec/support/helpers/test_env.rb:173:in `public_send'
                2025-03-06T10:44:53.974569Z 01O 	from /builds/gitlab-org/gitlab/spec/support/helpers/test_env.rb:173:in `block in init'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_runtime_exception",
                pattern: "RuntimeError"
              })
            end
          end

          describe 'bundler command failed' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-22T11:14:16.466238Z 01E You can add mutex_m to your Gemfile or gemspec to silence this warning.
                2025-01-22T11:14:17.317324Z 01E warning: parser/current is loading parser/ruby33, which recognizes 3.3.5-compliant syntax, but you are running 3.3.6.
                2025-01-22T11:14:17.317331Z 01E Please see https://github.com/whitequark/parser#compatibility-with-ruby-mri.
                2025-01-22T11:14:18.989698Z 01E bundler: failed to load command: bin/qa (bin/qa)
                2025-01-22T11:14:18.989995Z 01E /builds/gitlab-org/gitlab/qa/qa/page/validator.rb:48:in `validate!': Page views / elements validation error! (QA::Page::Validator::ValidationError)
                2025-01-22T11:14:18.989998Z 01E 	from /builds/gitlab-org/gitlab/qa/qa/scenario/test/sanity/selectors.rb:50:in `each'
                2025-01-22T11:14:18.990000Z 01E 	from /builds/gitlab-org/gitlab/qa/qa/scenario/test/sanity/selectors.rb:50:in `perform'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_bundler_command_failed",
                pattern: "bundler: failed to load command: "
              })
            end
          end

          describe 'generic ruby failure' do
            let(:trace_content) do
              <<~'TRACE'
                2025-03-06T11:31:15.373424Z 01O#{' '}
                2025-03-06T11:31:15.373424Z 01O   1) Group wikis behaves like User updates wiki page when wiki is empty redirects back to the home edit page
                2025-03-06T11:31:15.373425Z 01O      # Skipping ./ee/spec/features/groups/wikis_spec.rb[1:4:1:1] because it's been fast-quarantined.
                2025-03-06T11:31:15.373426Z 01O      Failure/Error: skip "Skipping #{example.id} because it's been fast-quarantined."
                2025-03-06T11:31:15.373427Z 01O        RSpec::Core::Pending::SkipDeclaredInExample
                2025-03-06T11:31:15.373428Z 01O      Shared Example Group: "User updates wiki page" called from ./ee/spec/features/groups/wikis_spec.rb:21
                2025-03-06T11:31:15.373428Z 01O      # ./spec/support/fast_quarantine.rb:20:in `block (2 levels) in <top (required)>'
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "ruby_generic_failure",
                pattern: "Failure/Error:"
              })
            end
          end

          describe 'make error' do
            let(:trace_content) do
              <<~'TRACE'
                2025-02-27T00:26:39.263140Z 01O ok  	gitlab.com/gitlab-org/gitlab/workhorse/internal/zipartifacts	2.074s
                2025-02-27T00:26:39.263149Z 01O FAIL
                2025-02-27T00:26:39.577862Z 01O make: Leaving directory '/builds/gitlab-org/gitlab/workhorse'
                2025-02-27T00:26:39.577954Z 01E make: *** [Makefile:73: test] Error 1
                2025-02-27T00:26:39.966888Z 00O section_end:1740615999:step_script
                2025-02-27T00:26:39.966894Z 00O+section_start:1740615999:cleanup_file_variables
                2025-02-27T00:26:39.969085Z 00O+Cleaning up project directory and file based variables
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "makefile",
                pattern: "make: .+ Error 1"
              })
            end
          end

          describe 'shell variable not bound' do
            let(:trace_content) do
              <<~'TRACE'
                2025-01-30T23:34:59.616882Z 01E Extracting archive to /builds/gitlab-org/gitlab/tmp/tests
                2025-01-30T23:34:59.619123Z 01E ==> 'download_and_extract_gitlab_workhorse_package' succeeded in 1 seconds.
                2025-01-30T23:35:00.869915Z 01O $ { # collapsed multi-line command
                2025-01-30T23:35:00.869780Z 01E /usr/bin/bash: line 437: output_file: unbound variable
                2025-01-30T23:35:01.862101Z 00O section_end:1738280101:step_script
                2025-01-30T23:35:01.862144Z 00O+section_start:1738280101:upload_artifacts_on_failure
                2025-01-30T23:35:01.865292Z 00O+Uploading artifacts for failed job
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "shell_unbound_variable",
                pattern: "unbound variable"
              })
            end
          end

          describe 'shell syntax error' do
            let(:trace_content) do
              <<~'TRACE'
                $ psql -h postgres -U $POSTGRES_USER -c 'create database gitlabhq_ci_test;'
                CREATE DATABASE
                $ cd $[[inputs.gem_path_prefix]]$[[inputs.gem_name]]/spec/fixtures/gitlab_fake && bundle install --retry=3
                /usr/bin/bash: line 348: [inputs.gem_path_prefix]: syntax error: operand expected (error token is "[inputs.gem_path_prefix]")
                Uploading artifacts for failed job
                Uploading artifacts...
                WARNING: coverage/: no matching files. Ensure that the artifact path is relative to the working directory (/builds/gitlab-org/gitlab)#{' '}
              TRACE
            end

            it 'returns the correct category' do
              expect(parser.process(trace_path)).to eq({
                failure_category: "shell_syntax",
                pattern: ": syntax error"
              })
            end
          end
        end

        describe 'shell permission denied' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-04T15:03:35.415032Z 01E WARNING: Upload request redirected                  location=https://gitlab.com/api/v4/jobs/9037602445/artifacts?artifact_format=zip&artifact_type=archive&expire_in=31d new-url=https://gitlab.com
              2025-02-04T15:03:35.415222Z 01E WARNING: Retrying...                                context=artifacts-uploader error=request redirected
              2025-02-04T15:03:44.679145Z 01E ERROR: Uploading artifacts as "archive" to coordinator... POST https://gitlab.com/api/v4/jobs/9037602445/artifacts: 403 Forbidden  id=9037602445 responseStatus=403 Forbidden status=403 token=glcbt-66
              2025-02-04T15:03:44.679264Z 01E FATAL: permission denied#{'                           '}
              2025-02-04T15:03:44.832011Z 00O section_end:1738681424:upload_artifacts_on_success
              2025-02-04T15:03:44.832016Z 00O+section_start:1738681424:cleanup_file_variables
              2025-02-04T15:03:44.832076Z 00O+Cleaning up project directory and file based variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "shell_permission",
              pattern: ": Permission denied"
            })
          end
        end

        describe 'shell file not found' do
          let(:trace_content) do
            <<~'TRACE'
              Install gems
              2025-03-05T16:57:38.784360Z 01O $ cd qa && bundle install
              2025-03-05T16:57:39.917400Z 01E#{' '}
              2025-03-05T16:57:39.918200Z 01E [!] There was an error parsing `Gemfile.next`: No such file or directory @ rb_sysopen - /builds/gitlab-org/gitlab/qa/Gemfile.next. Bundler cannot continue.
              2025-03-05T16:57:39.179280Z 00O section_end:1741193859:step_script
              2025-03-05T16:57:39.179291Z 00O+section_start:1741193859:after_script
              2025-03-05T16:57:39.180437Z 00O+Running after_script
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "shell_file_not_found",
              pattern: ": No such file or directory"
            })
          end
        end

        describe 'shell command not found' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-03T00:56:49.961350Z 01O /usr/local/bin/ruby: warning: Ruby was built without YJIT support. You may need to install rustc to build Ruby with YJIT.
              2025-02-03T00:56:49.232272Z 01O /usr/local/bin/ruby: warning: Ruby was built without YJIT support. You may need to install rustc to build Ruby with YJIT.
              2025-02-03T00:57:11.267828Z 01O main: line 434: gitlab_assets_archive_doesnt_exist || { echoinfo "INFO: Exiting early as package exists."; exit 0; }: command not found
              2025-02-03T00:56:48.537200Z 01E handle_exit_code: initial exit_status=1
              2025-02-03T00:57:11.281175Z 01O printing trace file: start
              Installing Yarn packages
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "shell_command_not_found",
              pattern: ": command not found"
            })
          end
        end

        describe 'shell variable is read-only' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-30T23:19:01.881705Z 01O 3.3G	.

              2025-01-30T23:19:01.968687Z 01O $ source scripts/prepare_build.sh
              2025-01-30T23:19:01.969935Z 01E scripts/utils.sh: line 533: ERROR_INFRASTRUCTURE: readonly variable
              2025-01-30T23:19:02.999180Z 00O section_end:1738279142:step_script
              2025-01-30T23:19:02.999220Z 00O+section_start:1738279142:cleanup_file_variables
              2025-01-30T23:19:02.101605Z 00O+Cleaning up project directory and file based variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "shell_readonly_variable",
              pattern: "readonly variable"
            })
          end
        end

        describe 'io error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-01-29T12:58:26.221345Z 01O OK: 25395 distinct packages available
              2025-01-29T12:58:26.311132Z 01O $ apk add ruby
              2025-01-29T12:58:26.682617Z 01O (1/8) Installing ca-certificates (20241121-r1)
              2025-01-29T12:58:26.795527Z 01E ERROR: ca-certificates-20241121-r1: IO ERROR
              2025-01-29T12:58:26.798743Z 01O (2/8) Installing gmp (6.3.0-r2)
              2025-01-29T12:58:26.906309Z 01O (3/8) Installing libffi (3.4.6-r0)
              2025-01-29T12:58:26.920019Z 01O (4/8) Installing libgcc (14.2.0-r4)
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "io",
              pattern: "ERROR: .+ IO ERROR"
            })
          end
        end

        describe 'could not curl error' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-06T10:07:10.437450Z 01O Fetching changes with git depth set to 20...
              2025-03-06T10:07:10.446570Z 01O Initialized empty Git repository in /builds/gitlab-org/gitlab/.git/
              2025-03-06T10:07:10.448381Z 01O Created fresh repository.
              2025-03-06T10:08:09.412630Z 01E error: RPC failed; HTTP 522 curl 22 The requested URL returned error: 522
              2025-03-06T10:08:09.412643Z 01E fatal: expected 'packfile'
              2025-03-06T10:08:09.609934Z 00O section_end:1741255689:get_sources
              2025-03-06T10:08:09.609944Z 00O+section_start:1741255689:upload_artifacts_on_failure
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "could_not_curl",
              pattern: "curl.+The requested URL returned error"
            })
          end
        end

        describe 'http bad request' do
          let(:trace_content) do
            <<~'TRACE'
              2025-02-26T14:05:21.886297Z 01E WARNING: Retrying...                                context=artifacts-uploader error=request redirected
              2025-02-26T14:05:25.234349Z 01E ERROR: Uploading artifacts as "archive" to coordinator... error  error=couldn't execute POST against https://gitlab.com/api/v4/jobs/9250196804/artifacts?artifact_format=zip&artifact_type=archive&expire_in=31d: Post "https://gitlab.com/api/v4/jobs/9250196804/artifacts?artifact_format=zip&artifact_type=archive&expire_in=31d": EOF id=9250196804 token=glcbt-66
              2025-02-26T14:05:25.234399Z 01E WARNING: Retrying...                                context=artifacts-uploader error=invalid argument
              2025-02-26T14:05:30.336365Z 01E WARNING: Uploading artifacts as "archive" to coordinator... POST https://gitlab.com/api/v4/jobs/9250196804/artifacts: 400 Bad Request (another artifact of the same type already exists)  id=9250196804 responseStatus=400 Bad Request status=400 token=glcbt-66
              2025-02-26T14:05:30.336373Z 01E FATAL: invalid argument#{'                            '}
              2025-02-26T14:05:30.493153Z 00O section_end:1740578730:upload_artifacts_on_success
              2025-02-26T14:05:30.493157Z 00O+section_start:1740578730:cleanup_file_variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "http",
              pattern: "400 Bad Request"
            })
          end
        end

        describe 'authentication failures' do
          let(:trace_content) do
            <<~'TRACE'
              2025-03-03T21:18:07.857613Z 01E+  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
              100   118  100   118    0     0    687      0 --:--:-- --:--:-- --:--:--   686 0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
              2025-03-03T21:18:08.200540Z 01O $ echo "$DEPENDENCY_REVIEW_PAT" | docker login --password-stdin -u "$DEPENDENCY_REVIEW_BOT_UNAME" -- "$DEPENDENCY_REVIEW_BOT_CI_REG"
              2025-03-03T21:18:08.259577Z 01E Error response from daemon: Get "https://registry.gitlab.com/v2/": unauthorized: HTTP Basic: Access denied. If a password was provided for Git authentication, the password was incorrect or you're required to use a token instead of a password. If a token was provided, it was either incorrect, expired, or improperly scoped. See https://gitlab.com/help/user/profile/account/two_factor_authentication_troubleshooting.md#error-http-basic-access-denied-if-a-password-was-provided-for-git-authentication-
              2025-03-03T21:18:08.408782Z 00O section_end:1741036688:step_script
              2025-03-03T21:18:08.408789Z 00O+section_start:1741036688:cleanup_file_variables
              2025-03-03T21:18:08.410657Z 00O+Cleaning up project directory and file based variables
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "authentication_failures",
              pattern: "HTTP Basic: Access denied"
            })
          end
        end

        describe 'unexpected error' do
          let(:trace_content) do
            <<~'TRACE'
              Setting up testing environment
              yarn install v1.22.19
              error An unexpected error occurred: "/builds/gitlab-org/gitlab-foss/package.json: Expected double-quoted property name in JSON at position 10350".
              info If you think this is a bug, please open a bug report with the information provided in "/builds/gitlab-org/gitlab-foss/yarn-error.log".
              info Visit https://yarnpkg.com/en/docs/cli/install for documentation about this command.
              2025-02-14T13:07:13.520154Z 01O [13:07:13] Retry attempts left: 2...
              yarn install v1.22.19
            TRACE
          end

          it 'returns the correct category' do
            expect(parser.process(trace_path)).to eq({
              failure_category: "unexpected",
              pattern: "An unexpected error occurred"
            })
          end
        end
      end
    end
  end

  describe 'pattern coverage' do
    let(:implementation) { described_class.new }

    it 'ensures all patterns defined in the class are tested' do
      defined_patterns = []
      defined_patterns += implementation.send(:patterns).map do |pattern_info|
        [pattern_info[:pattern], pattern_info[:failure_category]]
      end
      defined_patterns += implementation.send(:multiline_patterns).map do |pattern_info|
        [pattern_info[:pattern], pattern_info[:failure_category]]
      end
      defined_patterns += implementation.send(:catchall_patterns).map do |pattern_info|
        [pattern_info[:pattern], pattern_info[:failure_category]]
      end

      tested_categories = Set.new

      # Navigate through the example hierarchy to find all test cases
      RSpec.world.example_groups.each do |group|
        traverse_examples(group, tested_categories)
      end

      # Find patterns that are not tested
      untested_patterns = defined_patterns.select do |_, category|
        tested_categories.exclude?(category)
      end

      # Exclude certain patterns that might be intentionally not tested
      #
      # TODO: Strive to have this array empty by adding test-cases for each of them.
      excluded_categories = [
        'artifacts_not_found_404',
        'artifacts_upload_502',
        'build_gdk_image',
        'build_qa_image',
        'cng',
        'dependency-scanning_permission_denied',
        'docker_not_running',
        'e2e_lint',
        'e2e_specs',
        'e2e:code-suggestions-eval',
        'failed_to_open_tcp_connection',
        'failed_to_pull_image',
        'feature_flag_usage_check_failure',
        'gemnasium-python-dependency_scanning',
        'gitlab_too_much_load',
        'gitlab_unavailable',
        'http_500',
        'http_502',
        'kubernetes',
        'logs_too_big_to_analyze',
        'no_space_left',
        'package_hunter',
        'pg_query_canceled',
        'postgresql_unavailable',
        'rails-production-server-boot',
        'rake_change_in_worker_queues',
        'rake_invalid_feature_flag',
        'rake_new_version_of_sprockets',
        'rake_task_not_found',
        'redis',
        'rspec_at_80_min',
        'ruby_unknown_keyword',
        'ruby_wrong_number_of_arguments',
        'ruby_yjit_panick',
        'shell_could_not_gzip',
        'shell_not_in_function',
        'ssl_connect_reset_by_peer',
        'webpack_cli'
      ]

      untested_patterns.reject! { |_, category| excluded_categories.include?(category) }

      expect(untested_patterns).to be_empty,
        -> {
          untested_patterns = untested_patterns.map do |pattern, category|
            "  - '#{pattern}' (#{category})"
          end.join("\n")

          <<~ERROR
           The following patterns are not tested:\n#{untested_patterns}

           Please add test cases for these patterns.
          ERROR
        }
    end

    # Helper method to traverse the example group hierarchy
    def traverse_examples(group, tested_categories)
      group.examples.each do |example|
        next unless example.description == 'returns the correct category'

        # Extract the category from the example
        example.metadata[:block].source.scan(
          /expect\(parser\.process\(trace_path\)\)\.to eq\(\{[\s\n]*failure_category: ["']([^"']+)["']/m
        ).each do |match|
          tested_categories.add(match[0])
        end
      end

      # Recursively traverse child groups
      group.children.each do |child|
        traverse_examples(child, tested_categories)
      end
    end
  end
end
