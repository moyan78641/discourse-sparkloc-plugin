# frozen_string_literal: true

require "net/http"
require "json"

module ::DiscourseSparkloc
  class AppsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    # GET /sparkloc/apps.json — list current user's apps
    def index
      resp = proxy_get("/api/apps")
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # POST /sparkloc/apps.json — create app
    def create
      body = { name: params[:name], redirect_uris: params[:redirect_uris] }.to_json
      resp = proxy_post("/api/apps", body: body)
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # DELETE /sparkloc/apps/:id.json — delete app
    def destroy
      resp = proxy_delete("/api/apps/#{params[:id]}")
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # PUT /sparkloc/apps/:id.json — update app name/redirect_uris
    def update
      body = { name: params[:name], redirect_uris: params[:redirect_uris] }.to_json
      resp = proxy_put("/api/apps/#{params[:id]}", body: body)
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # POST /sparkloc/apps/:id/reset-secret.json — reset client secret
    def reset_secret
      resp = proxy_post("/api/apps/#{params[:id]}/reset-secret")
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # GET /sparkloc/authorizations.json — list user's authorized apps
    def authorizations
      resp = proxy_get("/api/authorizations")
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    # POST /sparkloc/authorizations/:id/revoke.json — revoke authorization
    def revoke_authorization
      resp = proxy_post("/api/authorizations/#{params[:id]}/revoke")
      render json: JSON.parse(resp.body), status: resp.code.to_i
    rescue => e
      render json: { error: e.message }, status: 502
    end

    private

    def backend_url
      SiteSetting.sparkloc_backend_url.chomp("/")
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 15
      http
    end

    # Forward the user's Discourse session as a Bearer token to Rust.
    # The Rust backend validates Bearer tokens via its own OIDC logic,
    # but for the plugin proxy we use the Discourse API key to fetch
    # user info and pass discourse_id. Instead, we forward the user's
    # own access token if present, or we call Rust with X-Discourse-User header.
    #
    # Simpler approach: the Ruby controller already verified the user is logged in.
    # We pass the discourse user id to Rust via a trusted internal header,
    # and Rust trusts it because of the X-API-Key.
    def proxy_get(path)
      uri = URI("#{backend_url}#{path}?discourse_id=#{current_user.id}")
      http = build_http(uri)
      req = Net::HTTP::Get.new(uri)
      req["X-API-Key"] = SiteSetting.sparkloc_internal_api_key
      http.request(req)
    end

    def proxy_post(path, body: nil)
      uri = URI("#{backend_url}#{path}?discourse_id=#{current_user.id}")
      http = build_http(uri)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["X-API-Key"] = SiteSetting.sparkloc_internal_api_key
      req.body = body if body
      http.request(req)
    end

    def proxy_delete(path)
      uri = URI("#{backend_url}#{path}?discourse_id=#{current_user.id}")
      http = build_http(uri)
      req = Net::HTTP::Delete.new(uri)
      req["X-API-Key"] = SiteSetting.sparkloc_internal_api_key
      http.request(req)
    end

    def proxy_put(path, body: nil)
      uri = URI("#{backend_url}#{path}?discourse_id=#{current_user.id}")
      http = build_http(uri)
      req = Net::HTTP::Put.new(uri)
      req["Content-Type"] = "application/json"
      req["X-API-Key"] = SiteSetting.sparkloc_internal_api_key
      req.body = body if body
      http.request(req)
    end
  end
end
