---
stage: AI-powered
group: Duo Workflow
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
title: GitLab Duo Workflow
---

{{< details >}}

- Tier: Ultimate
- Offering: GitLab.com
- Status: Experiment
- LLM: Anthropic [Claude 3.5 Sonnet](https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-3-5-sonnet)

{{< /details >}}

{{< history >}}

- [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/14153) in GitLab 17.4 [with a flag](../../administration/feature_flags.md) named `duo_workflow`. Enabled for GitLab team members only. This feature is an [experiment](../../policy/development_stages_support.md).

{{< /history >}}

{{< alert type="flag" >}}

The availability of this feature is controlled by a feature flag.
For more information, see the history.
This feature is available for internal GitLab team members for testing, but not ready for production use.

{{< /alert >}}

{{< alert type="warning" >}}

This feature is considered [experimental](../../policy/development_stages_support.md) and is not intended for customer usage outside of initial design partners. We expect major changes to this feature.

{{< /alert >}}

{{< alert type="disclaimer" />}}

GitLab Duo Workflow helps you complete development tasks directly in the VS Code integrated development environment (IDE).

Workflow:

- Runs in your IDE so that you do not have to switch contexts or tools.
- Creates and works through a plan, in response to your prompt.
- Stages proposed changes in your project's repository.
  You control when to accept, modify, or reject the suggestions.
- Understands the context of your project structure, codebase, and history.
  You can also add your own context, such as relevant GitLab issues or merge requests.

## Prerequisites

Before you can use Workflow, you must:

- [Install Visual Studio Code](https://code.visualstudio.com/download) (VS Code).
- [Set up the GitLab Workflow extension for VS Code](https://marketplace.visualstudio.com/items?itemName=GitLab.gitlab-workflow#setup). Minimum version 5.16.0.
- Have an account on GitLab.com.
- Have a project that meets the following requirements:
  - The project is on GitLab.com.
  - You have at least the Developer role.
  - The project belongs to a [group namespace](../namespace/_index.md) with an Ultimate subscription.
  - [Experimental features must be turned on](../gitlab_duo/turn_on_off.md#turn-on-beta-and-experimental-features).
  - [GitLab Duo must be turned on](../gitlab_duo/_index.md).
  - The repository you want to work with should be small or medium-sized.
    Workflow can be slow or fail for large repositories.

To isolate GitLab Duo Workflow in a Docker container, you must complete the [Docker setup](docker_set_up.md). This is not the preferred method to run Workflow.

## Use Workflow in VS Code

To use Workflow in VS Code:

1. In VS Code, open the Git repository folder for your GitLab project.
1. Check out the branch for the code you would like to change.
   - If you do not check out a GitLab project and branch, Workflow will not work.
1. Open the command palette:
   - On macOS: <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd>
   - On Windows and Linux: <kbd>Ctrl</kbd> + <kbd>P</kbd>.
1. Type `GitLab Duo Workflow` and select **GitLab: Show Duo Workflow**.
1. In the text box, specify a code task in detail.
   - For assistance writing your prompt, see [use case examples](use_cases.md) and [best practices](best_practices.md).
   - Workflow is aware of all files available to Git in the project branch.
   - You can also give Workflow [additional context](#the-context-workflow-is-aware-of).
   - Workflow cannot access external sources or the web.
1. Select **Start**.

After you describe your task, Workflow generates and executes on a plan to address it.
While it executes, you can pause or ask it to adjust the plan.

For more information about how to interact with Workflow, see [best practices](best_practices.md).

## The context Workflow is aware of

When you ask Workflow for help with a task, it is aware of some files by default.
You can also provide it with additional context.

| Area                          | How to use GitLab Workflow |
|-------------------------------|--------------------------------|
| Epics                         | Enter the epic ID and the name of the group the epic is in. The group must include a project that meets the project prerequisites. |
| Issues                        | Enter the issue ID if it's in the current project. You can also enter a project ID from a different project, as long as it meets the project prerequisites. |
| Local files                   | Workflow is aware of all files available to Git in the project branch. You can also reference a specific file by its file path. |
| Merge requests                | Enter the merge request ID if it's in the current project. You can also enter a project ID from a different project, as long as it meets the project prerequisites. |
| Merge request pipelines       | Enter the merge request ID that has the pipeline, if it's in the current project. You can also enter a project ID from a different project, as long as it meets the project prerequisites. |

Workflow also has access to the GitLab [Search API](../../api/search.md) to find related issues or merge requests.

## Supported languages

Workflow officially supports the following languages:

- CSS
- Go
- HTML
- Java
- JavaScript
- Markdown
- Python
- Ruby
- TypeScript

## APIs that Workflow has access to

To create solutions and understand the context of the problem,
Workflow accesses several GitLab APIs.

Specifically, an OAuth token with the `ai_workflows` scope has access
to the following APIs:

- [Projects API](../../api/projects.md)
- [Search API](../../api/search.md)
- [CI Pipelines API](../../api/pipelines.md)
- [CI Jobs API](../../api/jobs.md)
- [Merge Requests API](../../api/merge_requests.md)
- [Epics API](../../api/epics.md)
- [Issues API](../../api/issues.md)
- [Notes API](../../api/notes.md)
- [Usage Data API](../../api/usage_data.md)

## Audit log

An audit event is created for each API request done by Workflow.
On your GitLab Self-Managed instance, you can view these events on the
[instance audit events](../../administration/compliance/audit_event_reports.md#instance-audit-events) page.

## Give feedback

Workflow is an experiment and your feedback is crucial to improve it for you and others.
To report issues or suggest improvements,
[complete this survey](https://gitlab.fra1.qualtrics.com/jfe/form/SV_9GmCPTV7oH9KNuu).
