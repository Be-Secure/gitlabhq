import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { mount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import mockDeploymentFixture from 'test_fixtures/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import mockEnvironmentFixture from 'test_fixtures/graphql/deployments/graphql/queries/environment.query.graphql.json';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import ShowDeployment from '~/deployments/components/show_deployment.vue';
import DeploymentHeader from '~/deployments/components/deployment_header.vue';
import deploymentQuery from '~/deployments/graphql/queries/deployment.query.graphql';
import environmentQuery from '~/deployments/graphql/queries/environment.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const PROJECT_PATH = 'group/project';
const ENVIRONMENT_NAME = mockEnvironmentFixture.data.project.environment.name;
const DEPLOYMENT_IID = mockDeploymentFixture.data.project.deployment.iid;

describe('~/deployments/components/show_deployment.vue', () => {
  let wrapper;
  let mockApollo;
  let deploymentQueryResponse;
  let environmentQueryResponse;

  beforeEach(() => {
    deploymentQueryResponse = jest.fn();
    environmentQueryResponse = jest.fn();
  });

  const createComponent = () => {
    mockApollo = createMockApollo([
      [deploymentQuery, deploymentQueryResponse],
      [environmentQuery, environmentQueryResponse],
    ]);
    wrapper = mount(ShowDeployment, {
      apolloProvider: mockApollo,
      provide: {
        projectPath: PROJECT_PATH,
        environmentName: ENVIRONMENT_NAME,
        deploymentIid: DEPLOYMENT_IID,
      },
    });
    return waitForPromises();
  };

  const findHeader = () => wrapper.findComponent(DeploymentHeader);
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('errors', () => {
    it('shows an error message when the deployment query fails', async () => {
      deploymentQueryResponse.mockRejectedValue(new Error());
      await createComponent();

      expect(findAlert().text()).toBe(
        'There was an issue fetching the deployment, please try again later.',
      );
    });

    it('shows an error message when the environment query fails', async () => {
      environmentQueryResponse.mockRejectedValue(new Error());
      await createComponent();

      expect(findAlert().text()).toBe(
        'There was an issue fetching the deployment, please try again later.',
      );
    });

    it('captures exceptions for sentry', async () => {
      const error = new Error('oops!');
      deploymentQueryResponse.mockRejectedValue(error);
      await createComponent();

      expect(captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('header', () => {
    beforeEach(() => {
      deploymentQueryResponse.mockResolvedValue(mockDeploymentFixture);
      environmentQueryResponse.mockResolvedValue(mockEnvironmentFixture);
      return createComponent();
    });

    it('shows a header containing the deployment iid', () => {
      expect(wrapper.find('h1').text()).toBe(
        `Deployment #${mockDeploymentFixture.data.project.deployment.iid}`,
      );
    });

    it('shows the header component, binding the environment and deployment', () => {
      expect(findHeader().props()).toMatchObject({
        deployment: mockDeploymentFixture.data.project.deployment,
        environment: mockEnvironmentFixture.data.project.environment,
      });
    });
  });
});
