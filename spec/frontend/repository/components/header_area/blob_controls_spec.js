import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import WebIdeLink from 'ee_else_ce/vue_shared/components/web_ide_link.vue';
import { resetShortcutsForTests } from '~/behaviors/shortcuts';
import ShortcutsBlob from '~/behaviors/shortcuts/shortcuts_blob';
import Shortcuts from '~/behaviors/shortcuts/shortcuts';
import BlobLinePermalinkUpdater from '~/blob/blob_line_permalink_updater';
import BlobControls from '~/repository/components/header_area/blob_controls.vue';
import blobControlsQuery from '~/repository/queries/blob_controls.query.graphql';
import userGitpodInfo from '~/repository/queries/user_gitpod_info.query.graphql';
import createRouter from '~/repository/router';
import { updateElementsVisibility } from '~/repository/utils/dom';
import OverflowMenu from '~/repository/components/header_area/blob_overflow_menu.vue';
import OpenMrBadge from '~/repository/components/header_area/open_mr_badge.vue';
import { blobControlsDataMock, refMock, currentUserDataMock } from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/repository/utils/dom');
jest.mock('~/behaviors/shortcuts/shortcuts_blob');
jest.mock('~/blob/blob_line_permalink_updater');

describe('Blob controls component', () => {
  let router;
  let wrapper;
  let fakeApollo;

  const createComponent = async ({
    props = {},
    blobInfoOverrides = {},
    glFeatures = { blobOverflowMenu: false },
    routerOverride = {},
  } = {}) => {
    Vue.use(VueApollo);

    const projectPath = 'some/project';
    router = createRouter(projectPath, refMock);

    await router.push({
      name: 'blobPathDecoded',
      params: { path: '/some/file.js' },
      ...routerOverride,
    });

    const blobControlsMockResolver = jest.fn().mockResolvedValue({
      data: {
        project: {
          ...blobControlsDataMock,
          repository: {
            ...blobControlsDataMock.repository,
            blobs: {
              ...blobControlsDataMock.repository.blobs,
              nodes: [{ ...blobControlsDataMock.repository.blobs.nodes[0], ...blobInfoOverrides }],
            },
          },
        },
      },
    });

    const currentUserMockResolver = jest
      .fn()
      .mockResolvedValue({ data: { currentUser: currentUserDataMock } });

    await resetShortcutsForTests();

    fakeApollo = createMockApollo([
      [blobControlsQuery, blobControlsMockResolver],
      [userGitpodInfo, currentUserMockResolver],
    ]);

    wrapper = shallowMountExtended(BlobControls, {
      router,
      apolloProvider: fakeApollo,
      provide: {
        glFeatures,
        currentRef: refMock,
        gitpodEnabled: true,
      },
      propsData: {
        projectPath,
        projectIdAsNumber: 1,
        isBinary: false,
        refType: 'heads',
        ...props,
      },
      mixins: [{ data: () => ({ ref: refMock }) }, glFeatureFlagMixin()],
      stubs: {
        WebIdeLink: false,
      },
    });

    await waitForPromises();
  };

  const findOpenMrBadge = () => wrapper.findComponent(OpenMrBadge);
  const findFindButton = () => wrapper.findByTestId('find');
  const findBlameButton = () => wrapper.findByTestId('blame');
  const findPermalinkButton = () => wrapper.findByTestId('permalink');
  const findWebIdeLink = () => wrapper.findComponent(WebIdeLink);
  const findOverflowMenu = () => wrapper.findComponent(OverflowMenu);
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(async () => {
    await createComponent();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('showBlobControls', () => {
    it('should not render blob controls when filePath does not exist', async () => {
      await createComponent({
        routerOverride: { name: 'blobPathDecoded', params: null },
      });
      expect(wrapper.element).not.toBeVisible();
    });

    it('should not render blob controls when route name is not blobPathDecoded', async () => {
      await createComponent({
        routerOverride: { name: 'blobPath', params: { path: '/some/file.js' } },
      });
      expect(wrapper.element).not.toBeVisible();
    });
  });

  it.each`
    name                 | path
    ${'blobPathDecoded'} | ${null}
    ${'treePathDecoded'} | ${'myFile.js'}
  `(
    'does not render any buttons if router name is $name and router path is $path',
    async ({ name, path }) => {
      await router.replace({ name, params: { path } });

      await nextTick();

      expect(findFindButton().exists()).toBe(false);
      expect(findBlameButton().exists()).toBe(false);
      expect(findPermalinkButton().exists()).toBe(false);
      expect(updateElementsVisibility).toHaveBeenCalledWith('.tree-controls', true);
    },
  );

  it('loads the ShortcutsBlob', () => {
    expect(ShortcutsBlob).toHaveBeenCalled();
  });

  it('loads the BlobLinePermalinkUpdater', () => {
    expect(BlobLinePermalinkUpdater).toHaveBeenCalled();
  });

  describe('MR badge', () => {
    it('should render the badge if `filter_blob_path` flag is on', async () => {
      await createComponent({ glFeatures: { filterBlobPath: true } });
      expect(findOpenMrBadge().exists()).toBe(true);
      expect(findOpenMrBadge().props('blobPath')).toBe('/some/file.js');
      expect(findOpenMrBadge().props('projectPath')).toBe('some/project');
    });

    it('should not render the badge if `filter_blob_path` flag is off', async () => {
      await createComponent({ glFeatures: { filterBlobPath: false } });
      expect(findOpenMrBadge().exists()).toBe(false);
    });
  });

  describe('FindFile button', () => {
    it('renders FindFile button', () => {
      expect(findFindButton().exists()).toBe(true);
    });

    it('triggers a `focusSearchFile` shortcut when the findFile button is clicked', () => {
      const findFileButton = findFindButton();
      jest.spyOn(Shortcuts, 'focusSearchFile').mockResolvedValue();
      findFileButton.vm.$emit('click');

      expect(Shortcuts.focusSearchFile).toHaveBeenCalled();
    });

    it('emits a tracking event when the Find file button is clicked', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      jest.spyOn(Shortcuts, 'focusSearchFile').mockResolvedValue();

      findFindButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith('click_find_file_button_on_repository_pages');
    });
  });

  describe('Blame button', () => {
    it('renders a blame button with the correct href', () => {
      expect(findBlameButton().attributes('href')).toBe('blame/file.js');
    });

    it('does not render blame button when blobInfo.storedExternally is true', async () => {
      await createComponent({ blobInfoOverrides: { storedExternally: true } });

      expect(findBlameButton().exists()).toBe(false);
    });

    it('does not render blame button when blobInfo.externalStorage is "lfs"', async () => {
      await createComponent({
        blobInfoOverrides: { storedExternally: true, externalStorage: 'lfs' },
      });

      expect(findBlameButton().exists()).toBe(false);
    });

    it('renders blame button when blobInfo.storedExternally is false and externalStorage is not "lfs"', async () => {
      await createComponent({}, { storedExternally: false, externalStorage: null });

      expect(findBlameButton().exists()).toBe(true);
    });
  });

  it('renders a permalink button with the correct href', () => {
    expect(findPermalinkButton().attributes('href')).toBe('permalink/file.js');
  });

  it('does not render WebIdeLink component', () => {
    expect(findWebIdeLink().exists()).toBe(false);
  });

  describe('when blobOverflowMenu feature flag is true', () => {
    beforeEach(async () => {
      await createComponent({ glFeatures: { blobOverflowMenu: true } });
    });

    describe('WebIdeLink component', () => {
      it('renders the WebIdeLink component with the correct props', () => {
        expect(findWebIdeLink().props()).toMatchObject({
          showEditButton: false,
          editUrl: 'edit/blob/path/file.js',
          webIdeUrl: 'ide/blob/path/file.js',
          needsToFork: false,
          needsToForkWithWebIde: false,
          showPipelineEditorButton: true,
          pipelineEditorUrl: 'pipeline/editor/path/file.yml',
          gitpodUrl: 'gitpod/blob/url/file.js',
          showGitpodButton: true,
          gitpodEnabled: true,
        });
      });

      it('does not render WebIdeLink component if file is archived', async () => {
        await createComponent({
          blobInfoOverrides: {
            ...blobControlsDataMock.repository.blobs.nodes[0],
            archived: true,
          },
          glFeatures: { blobOverflowMenu: true },
        });
        expect(findWebIdeLink().exists()).toBe(false);
      });

      it('does not render WebIdeLink component if file is not editable', async () => {
        await createComponent({
          blobInfoOverrides: {
            ...blobControlsDataMock.repository.blobs.nodes[0],
            editBlobPath: '',
          },
          glFeatures: { blobOverflowMenu: true },
        });
        expect(findWebIdeLink().exists()).toBe(false);
      });
    });

    describe('BlobOverflow dropdown', () => {
      it('renders BlobOverflow component with correct props', () => {
        expect(findOverflowMenu().exists()).toBe(true);
        expect(findOverflowMenu().props()).toEqual({
          projectPath: 'some/project',
          isBinaryFileType: true,
          overrideCopy: true,
          isEmptyRepository: false,
          isUsingLfs: false,
          userPermissions: {
            __typename: 'ProjectPermissions',
            createMergeRequestIn: true,
            downloadCode: true,
            forkProject: true,
            pushCode: true,
          },
        });
      });

      it('passes the correct isBinaryFileType value to BlobOverflow when viewing a binary file', async () => {
        await createComponent({
          props: {
            isBinary: true,
          },
          glFeatures: {
            blobOverflowMenu: true,
          },
        });

        expect(findOverflowMenu().props('isBinaryFileType')).toBe(true);
      });

      it('copies to clipboard raw blob text, when receives copy event', () => {
        jest.spyOn(navigator.clipboard, 'writeText');
        findOverflowMenu().vm.$emit('copy');

        expect(navigator.clipboard.writeText).toHaveBeenCalledWith('Example raw text content');
      });
    });
  });
});
