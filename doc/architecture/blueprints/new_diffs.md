---
status: proposed
creation-date: "2023-10-10"
authors: [ "@iamphill" ]
coach: [ "@ntepluhina" ]
approvers: [ ]
owning-stage: "~devops::create"
participating-stages: []
---

<!-- Blueprints often contain forward-looking statements -->
<!-- vale gitlab.FutureTense = NO -->

# New diffs

## Summary

Diffs at GitLab are spread across several places with each area using their own method. We are aiming
to develop a single, performant way for diffs to be rendered across the application. Our aim here is
to improve all areas of diff rendering, from the backend creation of diffs to the frontend rendering
the diffs.

## Motivation

### Goals

- improved perceived performance
- improved maintainability
- consistent coverage of all scenarios

### Non-Goals

<!--
Listing non-goals helps to focus discussion and make progress. This section is
optional.

- What is out of scope for this blueprint?
-->

### Priority of Goals

In an effort to provide guidance on which goals are more important than others to assist in making
consistent choices, despite all goals being important, we defined the following order.

**Perceived performance** is above **improved maintainability** is above **consistent coverage**.

Examples:

- a proposal improves maintainability at the cost of perceived performance: ❌ we should consider an alternative.
- a proposal removes a feature from certain contexts, hurting coverage, and has no impact on perceived performance or maintanability: ❌ we should re-consider.
- a proposal improves perceived performance but removes features from certain contexts of usage: ✅ it's valid and should be discussed with Product/UX.
- a proposal guarantees consistent coverage and has no impact on perceived performance or maintainability: ✅ it's valid.

In essence, we'll strive to meet every goal at each decision but prioritise the higher ones.

## Proposal

<!--
This is where we get down to the specifics of what the proposal actually is,
but keep it simple!  This should have enough detail that reviewers can
understand exactly what you're proposing, but should not include things like
API designs or implementation. The "Design Details" section below is for the
real nitty-gritty.

You might want to consider including the pros and cons of the proposed solution so that they can be
compared with the pros and cons of alternatives.
-->

## Design and implementation details

### Workspace & Artifacts

- We will store implementation details like metrics, budgets, and development & architectural patterns here in the docs
- We will store large bodies of research, the results of audits, etc. in the [wiki](https://gitlab.com/gitlab-com/create-stage/new-diffs/-/wikis/home) of the [New Diffs project](https://gitlab.com/gitlab-com/create-stage/new-diffs)
- We will store audio & video recordings on the public Youtube channel in the Code Review / New Diffs playlist
- We will store drafts, meeting notes, and other temporary documents in public Google docs

### Definitions

#### Maintainability

Maintainable projects are _simple_ projects.

Simplicity is the opposite of complexity. This uses a definition of simple and complex [described by Rich Hickey in "Simple Made Easy"](https://www.infoq.com/presentations/Simple-Made-Easy/) (Strange Loop, 2011).

- Maintainable code is simple (single task, single concept, separate from other things).
- Maintainable projects expand on simple code by having simple structure (folders define classes of behaviors, e.g. you can be assured that a component directory will never initiate a network call, because that would be complecting visual display with data access)
- Maintainable applications flow out of simple organization and simple code. The old saying is a cluttered desk is representative of a cluttered mind. Rigorous discipline on simplicity will be represented in our output (the product). By being strict about working simply, we will naturally produce applications where our users can more easily reason about their behavior.

#### Done

GitLab has an existing [definition of done](/ee/development/contributing/merge_request_workflow.md#definition-of-done) which is geared primarily toward identifying when an MR is ready to be merged.

In addition to the items in the GitLab definition of done, work on new diffs should also adhere to the following requirements:

- Meets or exceeds all metrics
  - Meets or exceeds our minimum accessibility metrics (these are explicitly not part of our defined priorities, since they are non-negotiable)
- All work is fully documented for engineers (user documentation is a requirement of the standard definition of done)

<!--
This section should contain enough information that the specifics of your
change are understandable. This may include API specs (though not always
required) or even code snippets. If there's any ambiguity about HOW your
proposal will be implemented, this is the place to discuss them.

If you are not sure how many implementation details you should include in the
blueprint, the rule of thumb here is to provide enough context for people to
understand the proposal. As you move forward with the implementation, you may
need to add more implementation details to the blueprint, as those may become
an important context for important technical decisions made along the way. A
blueprint is also a register of such technical decisions. If a technical
decision requires additional context before it can be made, you probably should
document this context in a blueprint. If it is a small technical decision that
can be made in a merge request by an author and a maintainer, you probably do
not need to document it here. The impact a technical decision will have is
another helpful information - if a technical decision is very impactful,
documenting it, along with associated implementation details, is advisable.

If it's helpful to include workflow diagrams or any other related images.
Diagrams authored in GitLab flavored markdown are preferred. In cases where
that is not feasible, images should be placed under `images/` in the same
directory as the `index.md` for the proposal.
-->

## Alternative Solutions

<!--
It might be a good idea to include a list of alternative solutions or paths considered, although it is not required. Include pros and cons for
each alternative solution/path.

"Do nothing" and its pros and cons could be included in the list too.
-->
