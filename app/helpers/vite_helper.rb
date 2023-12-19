# frozen_string_literal: true

module ViteHelper
  def vite_enabled?
    # vite is not production ready yet
    return false if Rails.env.production?
    # Enable vite if explicitly turned on in the GDK
    return Gitlab::Utils.to_boolean(ViteRuby.env['VITE_ENABLED'], default: false) if ViteRuby.env.key?('VITE_ENABLED')

    # Enable vite the legacy way (in case GDK hasn't been updated)
    # This is going to be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/431041
    Rails.env.development? ? Feature.enabled?(:vite) : false
  end
end
