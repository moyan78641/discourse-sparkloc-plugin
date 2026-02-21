# frozen_string_literal: true

require "net/http"

module ::DiscourseSparkloc
  class MerchantsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr
    skip_before_action :redirect_to_login_if_required

    # GET /sparkloc/merchants — public, no auth
    def index
      uri = URI("#{backend_url}/api/merchants")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 15
      resp = http.request(Net::HTTP::Get.new(uri))
      render json: JSON.parse(resp.body)
    rescue => e
      render json: { error: e.message }, status: 502
    end

    private

    def backend_url
      SiteSetting.sparkloc_backend_url.chomp("/")
    end
  end
end
