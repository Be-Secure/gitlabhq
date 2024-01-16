# frozen_string_literal: true

module Organizations
  module OrganizationHelper
    def organization_show_app_data(organization)
      {
        organization: organization.slice(:id, :name, :description_html)
          .merge({ avatar_url: organization.avatar_url(size: 128) }),
        groups_and_projects_organization_path: groups_and_projects_organization_path(organization),
        # TODO: Update counts to use real data
        # https://gitlab.com/gitlab-org/gitlab/-/issues/424531
        association_counts: {
          groups: 10,
          projects: 5,
          users: 1050
        }
      }.merge(shared_groups_and_projects_app_data).to_json
    end

    def organization_new_app_data
      shared_new_settings_general_app_data.to_json
    end

    def organization_settings_general_app_data(organization)
      {
        organization: organization.slice(:id, :name, :path, :description)
          .merge({ avatar: organization.avatar_url(size: 192) })
      }.merge(shared_new_settings_general_app_data).to_json
    end

    def organization_groups_and_projects_app_data
      shared_groups_and_projects_app_data.to_json
    end

    def organization_index_app_data
      {
        new_organization_url: new_organization_path,
        organizations_empty_state_svg_path: image_path('illustrations/empty-state/empty-organizations-md.svg')
      }
    end

    def organization_user_app_data(organization)
      {
        organization_gid: organization.to_global_id,
        paths: organizations_users_paths
      }.to_json
    end

    def home_organization_setting_app_data
      {
        initial_selection: current_user.home_organization_id
      }.to_json
    end

    private

    def shared_groups_and_projects_app_data
      {
        projects_empty_state_svg_path: image_path('illustrations/empty-state/empty-projects-md.svg'),
        groups_empty_state_svg_path: image_path('illustrations/empty-state/empty-groups-md.svg'),
        new_group_path: new_group_path,
        new_project_path: new_project_path
      }
    end

    def shared_new_settings_general_app_data
      {
        preview_markdown_path: preview_markdown_organizations_path,
        organizations_path: organizations_path,
        root_url: root_url
      }
    end

    # See UsersHelper#admin_users_paths for inspiration to this method
    def organizations_users_paths
      {
        admin_user: admin_user_path(:id)
      }
    end
  end
end
