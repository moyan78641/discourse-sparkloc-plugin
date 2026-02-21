# frozen_string_literal: true

require "net/http"

module ::DiscourseSparkloc
  class OauthProxyController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    # OAuth2 endpoints are called by external apps and Discourse SSO,
    # not by Discourse's own Ember frontend.
    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required

    # GET /oauth-provider/auth → Rust /oauth2/auth
    # Returns 302 redirect to Discourse SSO
    def auth
      resp = proxy_get("/oauth2/auth?#{request.query_string}")
      passthrough_cookies(resp)
      handle_redirect_or_passthrough(resp)
    end

    # GET /oauth-provider/callback → Rust /oauth2/callback
    # Returns HTML consent page + Set-Cookie
    def callback
      resp = proxy_get("/oauth2/callback?#{request.query_string}")
      passthrough_cookies(resp)

      if resp.code.to_i == 200
        render html: resp.body.html_safe, status: 200, layout: false
      else
        handle_redirect_or_passthrough(resp)
      end
    end

    # POST /oauth-provider/authorize → Rust /oauth2/authorize
    # User clicked "允许", returns 302 redirect with code
    def authorize_user
      resp = proxy_post("/oauth2/authorize")
      passthrough_cookies(resp)
      handle_redirect_or_passthrough(resp)
    end

    # POST /oauth-provider/deny → Rust /oauth2/deny
    # User clicked "拒绝", returns 302 redirect with error
    def deny
      resp = proxy_post("/oauth2/deny")
      passthrough_cookies(resp)
      handle_redirect_or_passthrough(resp)
    end

    # POST /oauth-provider/token → Rust /oauth2/token
    # Returns JSON
    def token
      resp = proxy_post("/oauth2/token", body: request.raw_post)
      render body: resp.body, status: resp.code.to_i, content_type: "application/json"
    end

    # GET /oauth-provider/userinfo → Rust /oauth2/userinfo
    # Returns JSON
    def userinfo
      resp = proxy_get("/oauth2/userinfo")
      render body: resp.body, status: resp.code.to_i, content_type: "application/json"
    end

    # GET /oauth-provider/certs → Rust /oauth2/certs
    # Returns JSON
    def certs
      resp = proxy_get("/oauth2/certs")
      render body: resp.body, status: resp.code.to_i, content_type: "application/json"
    end

    # POST /oauth-provider/introspect → Rust /oauth2/introspect
    # Returns JSON
    def introspect
      resp = proxy_post("/oauth2/introspect", body: request.raw_post)
      render body: resp.body, status: resp.code.to_i, content_type: "application/json"
    end

    # POST /oauth-provider/revoke → Rust /oauth2/revoke
    # Returns 200 OK
    def revoke
      resp = proxy_post("/oauth2/revoke", body: request.raw_post)
      render body: resp.body, status: resp.code.to_i, content_type: resp["Content-Type"] || "text/plain"
    end

    # GET /.well-known/openid-configuration → Rust /.well-known/openid-configuration
    # Returns JSON
    def openid_configuration
      resp = proxy_get("/.well-known/openid-configuration")
      render body: resp.body, status: resp.code.to_i, content_type: "application/json"
    end

    private

    def backend_url
      SiteSetting.sparkloc_backend_url.chomp("/")
    end

    def proxy_get(path)
      uri = URI("#{backend_url}#{path}")
      http = build_http(uri)
      req = Net::HTTP::Get.new(uri)
      forward_headers(req)
      http.request(req)
    end

    def proxy_post(path, body: nil)
      uri = URI("#{backend_url}#{path}")
      http = build_http(uri)
      req = Net::HTTP::Post.new(uri)
      req.body = body if body
      req["Content-Type"] = request.content_type if request.content_type
      forward_headers(req)
      http.request(req)
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 30
      http
    end

    def forward_headers(req)
      # Forward Authorization header (for Bearer token endpoints)
      if request.headers["Authorization"]
        req["Authorization"] = request.headers["Authorization"]
      end
      # Forward Cookie (critical for oidc_session and consent_token)
      if request.headers["Cookie"]
        req["Cookie"] = request.headers["Cookie"]
      end
    end

    def passthrough_cookies(resp)
      # Rust may send multiple Set-Cookie headers
      resp.get_fields("Set-Cookie")&.each do |cookie_str|
        response.headers.add("Set-Cookie", cookie_str)
      end
    end

    def handle_redirect_or_passthrough(resp)
      if resp.is_a?(Net::HTTPRedirection) && resp["Location"]
        redirect_to resp["Location"], allow_other_host: true
      else
        render body: resp.body, status: resp.code.to_i,
               content_type: resp["Content-Type"] || "text/plain"
      end
    end
  end
end
