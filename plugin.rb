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
  plugin_root = File.dirname(__FILE__)
  %w[
    sparkloc_oauth_app
    sparkloc_authorization
    sparkloc_lottery_record
  ].each { |m| require File.join(plugin_root, "app", "models", m) }

  # Load scheduled jobs
  %w[
    check_canceled_subscriptions
    clean_old_authorizations
  ].each { |j| require File.join(plugin_root, "app", "jobs", "scheduled", j) }
end
