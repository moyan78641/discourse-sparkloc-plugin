# frozen_string_literal: true

# name: discourse-sparkloc-plugin
# about: Sparkloc OAuth2 Provider proxy, upgrade progress tab, and certified merchants page
# version: 0.1.0
# authors: Sparkloc
# url: https://sparkloc.com

module ::DiscourseSparkloc
  PLUGIN_NAME = "discourse-sparkloc-plugin"
end

require_relative "lib/discourse_sparkloc/engine"

enabled_site_setting :sparkloc_enabled

register_asset "stylesheets/common/sparkloc.scss"

after_initialize do
  register_svg_icon "arrow-up"
  register_svg_icon "certificate"
end
