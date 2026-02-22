# frozen_string_literal: true

# name: discourse-sparkloc-plugin
# about: Sparkloc OAuth2/OIDC Provider, upgrade progress, certified merchants, lottery and billing
# version: 0.3.0
# authors: Sparkloc
# url: https://sparkloc.com

module ::DiscourseSparkloc
  PLUGIN_NAME = "discourse-sparkloc-plugin"
end

require_relative "lib/discourse_sparkloc/engine"
require_relative "lib/discourse_sparkloc/jwt_provider"
require_relative "lib/discourse_sparkloc/sso_helper"

enabled_site_setting :sparkloc_enabled

register_asset "stylesheets/common/sparkloc.scss"

after_initialize do
  register_svg_icon "arrow-up"
  register_svg_icon "certificate"
  register_svg_icon "credit-card"
  register_svg_icon "book"
  register_svg_icon "info-circle"
  register_svg_icon "external-link-alt"
  register_svg_icon "dice"

  # Load ActiveRecord models
  %w[
    ../app/models/sparkloc_oauth_app
    ../app/models/sparkloc_authorization
    ../app/models/sparkloc_lottery_record
  ].each { |path| require_relative path }
end
