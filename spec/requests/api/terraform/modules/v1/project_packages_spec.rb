# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Terraform::Modules::V1::ProjectPackages, feature_category: :package_registry do
  include_context 'for terraform modules api setup'
  using RSpec::Parameterized::TableSyntax

  describe 'PUT /api/v4/projects/:project_id/packages/terraform/modules/:module_name/:module_system/:module_version/file/authorize' do
    include_context 'workhorse headers'

    let(:url) { api("/projects/#{project.id}/packages/terraform/modules/mymodule/mysystem/1.0.0/file/authorize") }
    let(:headers) { {} }

    subject { put(url, headers: headers) }

    context 'with valid project' do
      where(:visibility, :user_role, :member, :token_header, :token_type, :shared_examples_name, :expected_status) do
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'process terraform module workhorse authorization' | :success
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access'         | :forbidden
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :anonymous  | false | nil             | nil                    | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'process terraform module workhorse authorization' | :success
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access'         | :forbidden
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access'         | :not_found
        :private | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access'         | :not_found
        :private | :developer  | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :anonymous  | false | nil             | nil                    | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | true  | 'JOB-TOKEN'     | :job_token             | 'process terraform module workhorse authorization' | :success
        :public  | :guest      | true  | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access'         | :forbidden
        :public  | :guest      | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access'         | :forbidden
        :public  | :developer  | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :guest      | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | true  | 'JOB-TOKEN'     | :job_token             | 'process terraform module workhorse authorization' | :success
        :private | :guest      | true  | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access'         | :forbidden
        :private | :developer  | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access'         | :not_found
        :private | :guest      | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access'         | :not_found
        :private | :developer  | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :guest      | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | 'process terraform module workhorse authorization' | :success
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :invalid               | 'rejects terraform module packages access'         | :unauthorized
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | 'process terraform module workhorse authorization' | :success
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :invalid               | 'rejects terraform module packages access'         | :unauthorized
      end

      with_them do
        let(:headers) { user_headers.merge(workhorse_headers) }
        let(:user_headers) { user_role == :anonymous ? {} : { token_header => token } }

        before do
          project.update!(visibility: visibility.to_s)
        end

        it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
      end
    end
  end

  describe 'PUT /api/v4/projects/:project_id/packages/terraform/modules/:module_name/:module_system/:module_version/file' do
    include_context 'workhorse headers'

    let_it_be(:file_name) { 'module-system-v1.0.0.tgz' }

    let(:url) { "/projects/#{project.id}/packages/terraform/modules/mymodule/mysystem/1.0.0/file" }
    let(:headers) { {} }
    let(:params) { { file: temp_file(file_name) } }
    let(:file_key) { :file }
    let(:send_rewritten_field) { true }

    subject(:api_request) do
      workhorse_finalize(
        api(url),
        method: :put,
        file_key: file_key,
        params: params,
        headers: headers,
        send_rewritten_field: send_rewritten_field
      )
    end

    context 'with valid project' do
      where(:visibility, :user_role, :member, :token_header, :token_type, :shared_examples_name, :expected_status) do
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'process terraform module upload'          | :created
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access' | :forbidden
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :anonymous  | false | nil             | nil                    | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'process terraform module upload'          | :created
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access' | :forbidden
        :private | :developer  | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | true  | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access' | :not_found
        :private | :guest      | false | 'PRIVATE-TOKEN' | :personal_access_token | 'rejects terraform module packages access' | :not_found
        :private | :developer  | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | false | 'PRIVATE-TOKEN' | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :anonymous  | false | nil             | nil                    | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | true  | 'JOB-TOKEN'     | :job_token             | 'process terraform module upload'          | :created
        :public  | :guest      | true  | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access' | :forbidden
        :public  | :guest      | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access' | :forbidden
        :public  | :developer  | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :guest      | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | true  | 'JOB-TOKEN'     | :job_token             | 'process terraform module upload'          | :created
        :private | :guest      | true  | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access' | :forbidden
        :private | :developer  | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | true  | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access' | :not_found
        :private | :guest      | false | 'JOB-TOKEN'     | :job_token             | 'rejects terraform module packages access' | :not_found
        :private | :developer  | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :guest      | false | 'JOB-TOKEN'     | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | 'process terraform module upload'          | :created
        :public  | :developer  | true  | 'DEPLOY-TOKEN'  | :invalid               | 'rejects terraform module packages access' | :unauthorized
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :deploy_token          | 'process terraform module upload'          | :created
        :private | :developer  | true  | 'DEPLOY-TOKEN'  | :invalid               | 'rejects terraform module packages access' | :unauthorized
      end

      with_them do
        let(:user_headers) { user_role == :anonymous ? {} : { token_header => token } }
        let(:headers) { user_headers.merge(workhorse_headers) }
        let(:snowplow_gitlab_standard_context) do
          { project: project, namespace: project.namespace, user: snowplow_user,
            property: 'i_package_terraform_module_user' }
        end

        let(:snowplow_user) do
          case token_type
          when :deploy_token
            deploy_token
          when :job_token
            job.user
          else
            user
          end
        end

        before do
          project.update!(visibility: visibility.to_s)
        end

        it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
      end

      context 'when failed package file save' do
        let(:user_headers) { { 'PRIVATE-TOKEN' => personal_access_token.token } }
        let(:headers) { user_headers.merge(workhorse_headers) }

        before do
          project.add_developer(user)
        end

        it 'does not create package record', :aggregate_failures do
          allow(Packages::CreatePackageFileService).to receive(:new).and_raise(StandardError)

          expect { api_request }
              .to change { project.packages.count }.by(0)
              .and change { Packages::PackageFile.count }.by(0)
          expect(response).to have_gitlab_http_status(:error)
        end

        context 'with an existing package' do
          let_it_be_with_reload(:existing_package) do
            create(:terraform_module_package, name: 'mymodule/mysystem', version: '1.0.0', project: project)
          end

          it 'does not create a new package' do
            expect { api_request }
              .to change { project.packages.count }.by(0)
              .and change { Packages::PackageFile.count }.by(0)
            expect(response).to have_gitlab_http_status(:forbidden)
          end

          context 'when marked as pending_destruction' do
            it 'does create a new package' do
              existing_package.pending_destruction!

              expect { api_request }
                .to change { project.packages.count }.by(1)
                .and change { Packages::PackageFile.count }.by(1)
              expect(response).to have_gitlab_http_status(:created)
            end
          end
        end
      end
    end
  end
end
