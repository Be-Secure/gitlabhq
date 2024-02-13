import { autocompleteDataSources, markdownPreviewPath, isReference } from '~/work_items/utils';

describe('autocompleteDataSources', () => {
  beforeEach(() => {
    gon.relative_url_root = '/foobar';
  });

  it('returns correct data sources', () => {
    expect(autocompleteDataSources({ fullPath: 'project/group', iid: '2' })).toMatchObject({
      commands: '/foobar/project/group/-/autocomplete_sources/commands?type=WorkItem&type_id=2',
      labels: '/foobar/project/group/-/autocomplete_sources/labels?type=WorkItem&type_id=2',
      members: '/foobar/project/group/-/autocomplete_sources/members?type=WorkItem&type_id=2',
    });
  });

  it('returns correct data sources when group context', () => {
    expect(autocompleteDataSources({ fullPath: 'group', isGroup: true, iid: '2' })).toMatchObject({
      commands: '/foobar/groups/group/-/autocomplete_sources/commands?type=WorkItem&type_id=2',
      labels: '/foobar/groups/group/-/autocomplete_sources/labels?type=WorkItem&type_id=2',
      members: '/foobar/groups/group/-/autocomplete_sources/members?type=WorkItem&type_id=2',
    });
  });
});

describe('markdownPreviewPath', () => {
  beforeEach(() => {
    gon.relative_url_root = '/foobar';
  });

  it('returns corrrect data sources', () => {
    expect(markdownPreviewPath('project/group', '2')).toEqual(
      '/foobar/project/group/preview_markdown?target_type=WorkItem&target_id=2',
    );
  });
});

describe('isReference', () => {
  it.each`
    referenceId                                | result
    ${'#101'}                                  | ${true}
    ${'&101'}                                  | ${true}
    ${'101'}                                   | ${false}
    ${'#'}                                     | ${false}
    ${'&'}                                     | ${false}
    ${' &101'}                                 | ${false}
    ${'gitlab-org&101'}                        | ${true}
    ${'gitlab-org/project-path#101'}           | ${true}
    ${'gitlab-org/sub-group/project-path#101'} | ${true}
    ${'gitlab-org'}                            | ${false}
    ${'gitlab-org101#'}                        | ${false}
    ${'gitlab-org101&'}                        | ${false}
    ${'#gitlab-org101'}                        | ${false}
    ${'&gitlab-org101'}                        | ${false}
  `('returns $result for $referenceId', ({ referenceId, result }) => {
    expect(isReference(referenceId)).toEqual(result);
  });
});
