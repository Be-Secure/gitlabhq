---
stage: Data Stores
group: Tenant Scale
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Organization

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/409913) in GitLab 16.1 [with a flag](../../administration/feature_flags.md) named `ui_for_organizations`. Disabled by default.

FLAG:
This feature is not ready for production use.
On self-managed GitLab, by default this feature is not available. To make it available, an administrator can [enable the feature flag](../../administration/feature_flags.md) named `ui_for_organizations`.
On GitLab.com, this feature is not available.

DISCLAIMER:
This page contains information related to upcoming products, features, and functionality.
It is important to note that the information presented is for informational purposes only.
Please do not rely on this information for purchasing or planning purposes.
As with all projects, the items mentioned on this page are subject to change or delay.
The development, release, and timing of any products, features, or functionality remain at the
sole discretion of GitLab Inc.

NOTE:
Organization is in development.

Organization will be above the [top-level namespaces](../namespace/index.md) for you to manage
everything you do as a GitLab administrator, including:

- Defining and applying settings to all of your groups, subgroups, and projects.
- Aggregating data from all your groups, subgroups, and projects.

Our goal is to reach feature parity between SaaS and self-managed installations, with all
[Admin Area settings](../../administration/settings/index.md) moving to either:

- Groups. Available in the Organization, and subgroups.
- Hardware Controls. For functionality that does not apply to groups, Hardware Controls are only
  applicable to self-managed installations. There is one Hardware Controls section per installation.

For more information about the state of organization development,
see [epic 9265](https://gitlab.com/groups/gitlab-org/-/epics/9265).

<i class="fa fa-youtube-play youtube" aria-hidden="true"></i>
For a video introduction to the new hierarchy concept for groups and projects for epics, see
[Consolidating groups and projects update (August 2021)](https://www.youtube.com/watch?v=fE74lsG_8yM).

## View organizations

To view the organizations you have access to:

- On the left sidebar, select **Organizations** (**{organization}**).

## Create an organization

1. On the left sidebar, at the top, select **Create new** (**{plus}**) and **New organization**.
1. In the **Organization name** field, enter a name for the organization.
1. In the **Organization URL** field, enter a path for the organization.
1. Select **Create organization**.

## Edit an organization's name

1. On the left sidebar, select **Organizations** (**{organization}**) and find the organization you want to edit.
1. Select **Settings > General**.
1. Update the **Organization name** field.
1. Select **Save changes**.

## Manage groups and projects

1. On the left sidebar, select **Organizations** (**{organization}**) and find the organization you want to manage.
1. Select **Manage > Groups and projects**.
1. To switch between groups and projects, use the **Display** filter next to the search box.

## Manage users

1. On the left sidebar, select **Organizations** (**{organization}**) and find the organization you want to manage.
1. Select **Manage > Users**.

## Related topics

- [Organization developer documentation](../../development/organization/index.md)
