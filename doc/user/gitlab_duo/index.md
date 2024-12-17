---
stage: AI-powered
group: AI Framework
description: AI-powered features and functionality.
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# GitLab Duo

> - [First GitLab Duo features introduced](https://about.gitlab.com/blog/2023/05/03/gitlab-ai-assisted-features/) in GitLab 16.0.
> - [Removed third-party AI setting](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/136144) in GitLab 16.6.
> - [Removed support for OpenAI from all GitLab Duo features](https://gitlab.com/groups/gitlab-org/-/epics/10964) in GitLab 16.6.

GitLab Duo is a suite of AI-powered features that assist you while you work in GitLab.
These features aim to help increase velocity and solve key pain points across the software development lifecycle.

GitLab Duo features are available in [IDE extensions](../../editor_extensions/index.md) and the GitLab UI.
Some features are also available as part of [GitLab Duo Chat](../gitlab_duo_chat_examples.md).

- [Get started with GitLab Duo](../get_started/getting_started_gitlab_duo.md).
- [View a walkthrough of GitLab Duo Enterprise features](https://gitlab.navattic.com/duo-enterprise).

GitLab is [transparent](https://handbook.gitlab.com/handbook/values/#transparency).
As GitLab Duo features mature, the documentation will be updated to clearly state
how and where you can access these features.

## Generally available features

### GitLab Duo Chat

DETAILS:
**Tier:** Premium with GitLab Duo Pro, Ultimate with GitLab Duo Pro or Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

- Help you write and understand code faster, get up to speed on the status of projects,
  and quickly learn about GitLab by answering your questions in a chat window.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=ZQBAuf-CTAY&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED)
- [View documentation](../gitlab_duo_chat/index.md).

### Discussion Summary

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps everyone get up to speed by summarizing the lengthy conversations in an issue.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=IcdxLfTIUgc)
- [View documentation](../discussions/index.md#summarize-issue-discussions-with-duo-chat).

### Code Suggestions

DETAILS:
**Tier:** Premium with GitLab Duo Pro, Ultimate with GitLab Duo Pro or Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

- Helps you write code more efficiently by generating code and showing suggestions as you type.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://youtu.be/ds7SG1wgcVM)
- [View documentation](../project/repository/code_suggestions/index.md).

### Code Explanation

DETAILS:
**Tier:** Premium with GitLab Duo Pro, Ultimate with GitLab Duo Pro or Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

- Helps you understand the selected code by explaining it more clearly.
- View documentation for explaining code in:
  - [The IDE](../gitlab_duo_chat/examples.md#explain-selected-code).
  - [A file](../../user/project/repository/code_explain.md).
  - [A merge request](../../user/project/merge_requests/changes.md#explain-code-in-a-merge-request).

### Test Generation

DETAILS:
**Tier:** Premium with GitLab Duo Pro, Ultimate with GitLab Duo Pro or Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

- Helps catch bugs early by generating tests for the selected code.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=zWhwuixUkYU&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED)
- [View documentation](../gitlab_duo_chat/examples.md#write-tests-in-the-ide).

### Refactor Code

DETAILS:
**Tier:** Premium with GitLab Duo Pro, Ultimate with GitLab Duo Pro or Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

- Improve or refactor the selected code.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=zWhwuixUkYU&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED)
- [View documentation](../gitlab_duo_chat/examples.md#refactor-code-in-the-ide).

### Fix Code

DETAILS:
**Tier:** Premium with GitLab Duo Pro, Ultimate with GitLab Duo Pro or Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

- Fix quality problems such as bugs or typos in the selected code.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=zWhwuixUkYU&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED)
- [View documentation](../gitlab_duo_chat/examples.md#fix-code-in-the-ide).

### GitLab Duo for the CLI

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- `glab duo ask` helps you discover or recall `git` commands when and where you need them.
- [View documentation](../../editor_extensions/gitlab_cli/index.md#gitlab-duo-for-the-cli).

### Merge Commit Message Generation

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps you merge more quickly by generating meaningful commit messages.
- [View documentation](../project/merge_requests/duo_in_merge_requests.md#generate-a-merge-commit-message).

### Root Cause Analysis

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/123692) in GitLab 16.2 as an [experiment](../../policy/development_stages_support.md#experiment) on GitLab.com.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/441681) and moved to GitLab Duo Chat in GitLab 17.3.
> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps you determine the root cause for a CI/CD job failure by analyzing the logs.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=MLjhVbMjFAY&list=PLFGfElNsQthZGazU1ZdfDpegu0HflunXW)
- [View documentation](../gitlab_duo_chat/examples.md#troubleshoot-failed-cicd-jobs-with-root-cause-analysis).

### Vulnerability Explanation

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps you understand vulnerabilities, how they can be exploited, and how to fix them.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=MMVFvGrmMzw&list=PLFGfElNsQthZGazU1ZdfDpegu0HflunXW)
- [View documentation](../application_security/vulnerabilities/index.md#explaining-a-vulnerability).

### AI Impact Dashboard

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Measure the AI effectiveness and impact on SDLC metrics.
- Visualize which metrics improved as a result of investments in AI.
- Compare the performance of teams that are using AI against teams that are not using AI.
- Track the progress of AI adoption.
- [View documentation](../analytics/ai_impact_analytics.md).

## Beta features

### Self-Hosted Models

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** Self-managed
**Status:** Beta

> - [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/12972) in GitLab 17.1 [with a flag](../../administration/feature_flags.md) named `ai_custom_model`. Disabled by default.
> - [Enabled on self-managed](https://gitlab.com/groups/gitlab-org/-/epics/15176) in GitLab 17.6.
> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

Host the language models that power AI features in GitLab. Code Suggestions and Duo Chat are supported.

You can use language model vendors provided by GitLab or fully manage specific language models in your self-hosted environment.

- Use GitLab model vendors: Connect with default external model providers, like Google Vertex AI or Anthropic, by
  using the GitLab-managed AI gateway.
- Host your own models: Deploy and manage your own AI gateway and language models in your infrastructure,
  without depending on GitLab-provided external language providers.
- [View documentation](../../administration/self_hosted_models/index.md).

### Merge Request Summary

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com
**Status:** Beta

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps populate a merge request more quickly by generating a description based on the code changes.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=CKjkVsfyFd8&list=PLFGfElNsQthZGazU1ZdfDpegu0HflunXW)
- [View documentation](../project/merge_requests/duo_in_merge_requests.md#generate-a-description-by-summarizing-code-changes).

### Vulnerability Resolution

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com, Self-managed, GitLab Dedicated
**Status:** Beta

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Help resolve a vulnerability by generating a merge request that addresses it.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=VJmsw_C125E&list=PLFGfElNsQthZGazU1ZdfDpegu0HflunXW)
- [View documentation](../application_security/vulnerabilities/index.md#vulnerability-resolution).

## Experimental features

### Issue Description Generation

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com
**Status:** Experiment

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps populate an issue more quickly by generating a more in-depth description, based on a short summary you provide.
- [View documentation](../project/issues/managing_issues.md#populate-an-issue-with-issue-description-generation).

### Code Review

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com
**Status:** Experiment

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Automated code review of the proposed changes in your merge request.
- [View documentation](../project/merge_requests/duo_in_merge_requests.md#have-gitlab-duo-review-your-code).

### Code Review Summary

DETAILS:
**Tier:** Ultimate with GitLab Duo Enterprise - [Start a trial](https://about.gitlab.com/solutions/gitlab-duo-pro/sales/?type=free-trial)
**Offering:** GitLab.com
**Status:** Experiment

> - Changed to require GitLab Duo add-on in GitLab 17.6 and later.

- Helps make merge request handover to reviewers easier by summarizing all the comments in a merge request review.
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [Watch overview](https://www.youtube.com/watch?v=Bx6Zajyuy9k&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED)
- [View documentation](../project/merge_requests/duo_in_merge_requests.md#summarize-a-code-review).

### GitLab Duo Workflow

DETAILS:
**Tier:** Ultimate
**Offering:** GitLab.com
**Status:** Experiment

- Automate tasks and help increase productivity in your development workflow.
- [View documentation](../duo_workflow/index.md).

## Disable GitLab Duo features for specific groups or projects or an entire instance

Disable GitLab Duo features by [following these instructions](turn_on_off.md).
