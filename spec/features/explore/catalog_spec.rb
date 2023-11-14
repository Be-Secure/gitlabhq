# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Global Catalog', :js, feature_category: :pipeline_composition do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:user) { create(:user) }

  before_all do
    namespace.add_developer(user)
  end

  before do
    sign_in(user)
  end

  describe 'GET explore/catalog' do
    let_it_be(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:ci_resource_projects) do
      create_list(
        :project,
        3,
        :repository,
        description: 'A simple component',
        namespace: namespace
      )
    end

    before do
      ci_resource_projects.each do |current_project|
        create(:ci_catalog_resource, project: current_project)
      end

      visit explore_catalog_index_path
      wait_for_requests
    end

    it 'shows CI Catalog title and description', :aggregate_failures do
      expect(page).to have_content('CI/CD Catalog')
      expect(page).to have_content('Discover CI configuration resources for a seamless CI/CD experience.')
    end

    it 'renders CI Catalog resources list' do
      expect(find_all('[data-testid="catalog-resource-item"]').length).to be(3)
    end

    context 'for a single CI/CD catalog resource' do
      it 'renders resource details', :aggregate_failures do
        within_testid('catalog-resource-item', match: :first) do
          expect(page).to have_content(ci_resource_projects[2].name)
          expect(page).to have_content(ci_resource_projects[2].description)
          expect(page).to have_content(namespace.name)
        end
      end

      context 'when clicked' do
        before do
          find_by_testid('ci-resource-link', match: :first).click
        end

        it 'navigate to the details page' do
          expect(page).to have_content('Go to the project')
        end
      end
    end
  end

  describe 'GET explore/catalog/:id' do
    let_it_be(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:new_ci_resource) { create(:ci_catalog_resource, project: project) }

    before do
      visit explore_catalog_path(id: new_ci_resource["id"])
    end

    it 'navigates to the details page' do
      expect(page).to have_content('Go to the project')
    end
  end
end
