# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', :orchestrated, :oauth, product_group: :authentication do
    describe 'OAuth' do
      it 'logs in with Facebook credentials',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/417115',
        quarantine: {
          type: :waiting_on,
          issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/431392'
        } do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)

        Page::Main::Login.perform(&:sign_in_with_facebook)

        Vendor::Facebook::Page::Login.perform(&:login)

        expect(page).to have_content('Welcome to GitLab')
      end
    end
  end
end
