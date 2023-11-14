# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ml::Mlflow::ModelVersions, feature_category: :mlops do
  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user).tap { |u| project.add_developer(u) } }
  let_it_be(:another_project) { build(:project).tap { |p| p.add_developer(developer) } }

  let_it_be(:name) { 'a-model-name' }
  let_it_be(:version) { '0.0.1' }
  let_it_be(:model) { create(:ml_models, project: project, name: name) }
  let_it_be(:model_version) { create(:ml_model_versions, project: project, model: model, version: version) }

  let_it_be(:tokens) do
    {
      write: create(:personal_access_token, scopes: %w[read_api api], user: developer),
      read: create(:personal_access_token, scopes: %w[read_api], user: developer),
      no_access: create(:personal_access_token, scopes: %w[read_user], user: developer),
      different_user: create(:personal_access_token, scopes: %w[read_api api], user: build(:user))
    }
  end

  let(:current_user) { developer }
  let(:access_token) { tokens[:write] }
  let(:headers) { { 'Authorization' => "Bearer #{access_token.token}" } }
  let(:project_id) { project.id }
  let(:default_params) { {} }
  let(:params) { default_params }
  let(:request) { get api(route), params: params, headers: headers }
  let(:json_response) { Gitlab::Json.parse(api_response.body) }

  subject(:api_response) do
    request
    response
  end

  describe 'GET /projects/:id/ml/mlflow/api/2.0/mlflow/model_versions/get' do
    let(:route) do
      "/projects/#{project_id}/ml/mlflow/api/2.0/mlflow/model_versions/get?name=#{name}&version=#{version}"
    end

    it 'returns the model version', :aggregate_failures do
      is_expected.to have_gitlab_http_status(:ok)
      expect(json_response['model_version']).not_to be_nil
      expect(json_response['model_version']['name']).to eq(name)
      expect(json_response['model_version']['version']).to eq(version)
    end

    describe 'Error States' do
      context 'when has access' do
        context 'and model name in incorrect' do
          let(:route) do
            "/projects/#{project_id}/ml/mlflow/api/2.0/mlflow/model_versions/get?name=--&version=#{version}"
          end

          it_behaves_like 'MLflow|Not Found - Resource Does Not Exist'
        end

        context 'and version in incorrect' do
          let(:route) do
            "/projects/#{project_id}/ml/mlflow/api/2.0/mlflow/model_versions/get?name=#{name}&version=--"
          end

          it_behaves_like 'MLflow|Not Found - Resource Does Not Exist'
        end

        context 'when user lacks read_model_registry rights' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?)
                                .with(current_user, :read_model_registry, project)
                                .and_return(false)
          end

          it "is Not Found" do
            is_expected.to have_gitlab_http_status(:not_found)
          end
        end
      end

      it_behaves_like 'MLflow|shared model registry error cases'
      it_behaves_like 'MLflow|Requires read_api scope'
    end
  end
end
