# frozen_string_literal: true

require "net/http"
require "json"

module ::DiscourseSparkloc
  class MerchantsAdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    # POST /sparkloc/admin/merchants
    def create
      resp = proxy_to_rust(:post, "/api/merchants",
        body: merchant_params.to_json)
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # PUT /sparkloc/admin/merchants/:id
    def update
      resp = proxy_to_rust(:put, "/api/merchants/#{params[:id]}",
        body: merchant_params.to_json)
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # DELETE /sparkloc/admin/merchants/:id
    def destroy
      resp = proxy_to_rust(:delete, "/api/merchants/#{params[:id]}")
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    private

    def merchant_params
      p = params.permit(:name, :logo_url, :website, :discourse_username, :description, :sort_order)
      p[:sort_order] = p[:sort_order].to_i if p[:sort_order].present?
      p
    end

    def proxy_to_rust(method, path, body: nil)
      uri = URI("#{backend_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 15

      case method
      when :post
        req = Net::HTTP::Post.new(uri)
      when :put
        req = Net::HTTP::Put.new(uri)
      when :delete
        req = Net::HTTP::Delete.new(uri)
      end

      req["Content-Type"] = "application/json"
      req["X-API-Key"] = SiteSetting.sparkloc_internal_api_key
      req.body = body if body

      http.request(req)
    end

    def backend_url
      SiteSetting.sparkloc_backend_url.chomp("/")
    end
  end
end
