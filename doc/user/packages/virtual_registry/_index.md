---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
title: Virtual Registry
---

{{< details >}}

- Tier: Premium, Ultimate
- Offering: GitLab.com, GitLab Self-Managed
- Status: Experiment

{{< /details >}}

{{< history >}}

- [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/14137) in GitLab 18.0 [with a flag](../../../administration/feature_flags.md) named `virtual_registry_maven`. Disabled by default.

{{< /history >}}

{{< alert type="flag" >}}

The availability of this feature is controlled by a feature flag.
For more information, see the history.
This feature is available in [experiment](../../../policy/development_stages_support.md#experiment).
Review the documentation carefully before you use this feature.

{{< /alert >}}

Use the GitLab virtual registry to proxy, cache, and distribute packages from multiple upstream registries behind a single, well-known URL.

With this approach, you can configure your applications to use one virtual registry instead of multiple upstream registries.

## Prerequisites

To configure the virtual registry:

- You need a top-level group with a GitLab license with at least the premium level.
- You must be at least Maintainer of the top-level group.
- Make sure you enable the dependency proxy setting. It's enabled by default, but [administrators can turn it off](../../../administration/packages/dependency_proxy.md).
- You must configure authentication for your supported [package format](#supported-package-formats).

## Supported package formats

- [Maven packages](maven/_index.md)

## Virtual registry workflow

When you create a virtual registry:

- The registry is hosted at a top-level Group for a given package format. Projects and subgroups are not supported.
- The virtual registry object links to an ordered list of available upstreams (up to 20). Each upstream points to an external registry.
- External registries can be public or private. Credentials for private registries are stored in the upstream itself, so you do not need to store them in the package manager configuration.

When a virtual registry receives a request for a package:

- The registry walks through the ordered list of upstreams to find one that can fulfill the request.
- If the requested file is found in an upstream, the virtual registry returns that file and caches it for future requests. [Caching](#caching-system) increases the availability of dependencies if you've pulled them at least once through the virtual registry.

### Caching system

All upstream registries have a caching system. A caching system stores request paths in a cache entry, and serves the responses for identical requests from the GitLab virtual registry. This way, the virtual registry does not have to contact the upstream again when the same package is requested.

If a requested path has not been cached in any of the available upstreams:

1. The virtual registry walks through the ordered list of upstreams to find one that can fulfill the request.
1. When an upstream is found that can fulfill the request, the virtual registry pulls the response from the upstream with the provided credentials if necessary.

If the requested path has been cached in any of the available upstreams:

1. The virtual registry checks the [cache validity period](#cache-validity-period) to see if the cache entry needs to be refreshed before forwarding the response.
1. If the cache is valid, the cache entry of the upstream fulfills the request.
   - At this point, notice the virtual registry does not walk through the ordered list of upstreams again. If a lower priority upstream has cached the request, and a higher priority upstream has the requested file but not in its cache, the request is fulfilled with the lower priority upstream cache entry. This is by design.

If an upstream can't be found to fulfill the request, the virtual registry returns a `404 Not Found` error.

#### Cache validity period

The cache validity period sets the amount of time, in hours,
that a cache entry is considered valid to fulfill a request.

Before the virtual registry pulls from an existing cache entry,
it checks the cache validity period to determine if the entry must be refreshed or not.

If the entry is outside the validity period, the virtual registry checks if the upstream response is identical to the one in the cache. If:

- The response is identical, the entry is used to fulfill the request.
- The response is not identical, the response is downloaded again from the upstream to overwrite the upstream cache entry.

If network conditions prevent the virtual registry from connecting to the upstream, the caching system uses the available cache entry to serve the request. This way, as long as the virtual registry has the response related to a request in the cache, that request is fulfilled, even when outside the validity period.

##### Set the cache validity period

The cache validity period is important in the overall performance of the virtual registry to fulfill requests. Contacting external registries is a costly operation. Smaller validity periods increase the amount of checks, and longer periods decrease them.

You can turn off cache validity checks by setting it to 0.

The default value of the cache validity period is 24 hours.

You should set the cache validity period to 0 when the external registry targeted by the upstream is known to have immutable responses. This is often the case when using official public registries. For more information, check your [supported package format](#supported-package-formats).

### Object storage usage

Cache entries save their files in object storage in [the `dependency_proxy` bucket](../../../administration/object_storage.md#configure-the-parameters-of-each-object).

Object storage usage counts towards the top-level group [object storage usage limit](../../storage_usage_quotas.md#view-storage).

## Performance considerations

Virtual registry performance might vary based on factors like:

- Whether or not a requested file is cached from an upstream registry
- How quickly upstream registries can respond if a file exists or not
- Which client is pulling dependencies, and the proximity of the client to the GitLab instance

### Tradeoffs

Virtual registries are more advanced than public registries. When you pull dependencies with a virtual registry, it might take longer than other registries, such as public, official registries.

Compared with public registries, virtual registries also support multiple upstream registries and authentication, but these advantages are not free.

### Upstream prioritization

Upstream registries are organized in ordered lists. Whenever a request is not
found in a cache, the virtual registry walks the ordered list to find the
upstream with the highest priority that can fulfill the request.
This system noticeably impacts the performance of a virtual registry.

When you manage a list of private upstream registries:

- You should prioritize registries with the most packages at the top of the list. This approach:
  - Increases the chances that a high-priority registry can fulfill the request
  - Prevents walking the entire ordered list to find a valid upstream registry
- You should put registries that host the least amount of packages at the bottom of the list.

### Performance improvements with usage

When you create a virtual registry, the cache of each configured upstream is empty. Each request requires the virtual registry to walk the list of available upstream registries to fulfill a request. These initial requests take longer to fulfill.

When an upstream registry caches a request, the time to fulfill an identical request decreases. Over time, the overall performance of the virtual registry improves as more upstream registries cache more requests.

### Use the CI/CD cache

GitLab CI/CD jobs can further increase their performance by [using caching in GitLab CI/CD](../../../ci/caching/_index.md#common-use-cases-for-caches) for dependencies.

By using caching in the CI/CD cache, jobs can avoid downloading dependencies from the virtual registry, which improves the execution time.

However, this enhancement comes with the cost of duplicating the storage for each dependency. Each dependency is stored in the virtual registry and the CI/CD cache.
