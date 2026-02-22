# frozen_string_literal: true

require "securerandom"

module ::DiscourseSparkloc
  class Oauth2Controller < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required

    # GET /oauth-provider/auth
    def auth
      client_id = params[:client_id]
      redirect_uri = params[:redirect_uri]

      app = find_app_by_client_id(client_id)
      unless app
        return render plain: "unknown client_id", status: 400
      end

      allowed = app["redirect_uris"].split(",").map(&:strip)
      unless allowed.include?(redirect_uri)
        return render plain: "redirect_uri not registered for this app", status: 400
      end

      session_id = SecureRandom.uuid
      nonce = SecureRandom.uuid

      inflight = {
        nonce: nonce,
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: params[:scope] || "openid",
        state: params[:state],
        response_type: params[:response_type],
        oidc_nonce: params[:nonce],
      }

      Rails.cache.write("oidc_session::#{session_id}", inflight, expires_in: 10.minutes)

      cookies[:oidc_session] = { value: session_id, path: "/", expires: 10.minutes.from_now }

      callback_url = "#{issuer_url}/callback"
      sso_url = sso_helper.generate_sso_url(callback_url, nonce)
      redirect_to sso_url, allow_other_host: true
    end

    # GET /oauth-provider/callback
    def callback
      session_id = cookies[:oidc_session]
      unless session_id.present?
        return render plain: "invalid session, please try again", status: 400
      end

      inflight = Rails.cache.read("oidc_session::#{session_id}")
      unless inflight
        return render plain: "invalid session, please try again", status: 400
      end
      Rails.cache.delete("oidc_session::#{session_id}")

      begin
        sso_params = sso_helper.validate_response(params[:sso], params[:sig], inflight[:nonce])
      rescue => e
        return render plain: "authentication failed: #{e.message}", status: 400
      end

      # Build user info from SSO response
      username = sso_params["username"]
      discourse_user = User.find_by(username: username)

      trust_level = discourse_user&.trust_level || 0
      avatar_url = sso_params["avatar_url"] || ""
      external_id = sso_params["external_id"]
      name = sso_params["name"] || username

      # Look up app name
      app = find_app_by_client_id(inflight[:client_id])
      app_name = app ? app["name"] : inflight[:client_id]

      # Store pending consent
      consent_token = SecureRandom.uuid
      pending = {
        client_id: inflight[:client_id],
        app_name: app_name,
        redirect_uri: inflight[:redirect_uri],
        scope: inflight[:scope],
        state: inflight[:state],
        oidc_nonce: inflight[:oidc_nonce],
        user: {
          external_id: external_id,
          username: username,
          name: name,
          email: sso_params["email"] || "",
          avatar_url: avatar_url,
          trust_level: trust_level,
        },
      }

      Rails.cache.write("consent::#{consent_token}", pending, expires_in: 10.minutes)

      cookies.delete(:oidc_session)
      cookies[:consent_token] = { value: consent_token, path: "/", expires: 10.minutes.from_now }

      # Render consent page
      html = render_consent_page(pending[:user], app_name)
      render html: html.html_safe, layout: false
    end

    # POST /oauth-provider/authorize
    def authorize_user
      consent_token = cookies[:consent_token]
      unless consent_token.present?
        return render plain: "invalid session, please try again", status: 400
      end

      pending = Rails.cache.read("consent::#{consent_token}")
      unless pending
        return render plain: "consent expired, please try again", status: 400
      end
      Rails.cache.delete("consent::#{consent_token}")

      # Generate authorization code
      code = SecureRandom.hex(32)
      entry = {
        client_id: pending[:client_id],
        redirect_uri: pending[:redirect_uri],
        user: pending[:user],
        scope: pending[:scope],
        oidc_nonce: pending[:oidc_nonce],
      }
      Rails.cache.write("auth_code::#{code}", entry, expires_in: 5.minutes)

      # Build redirect
      uri = URI.parse(pending[:redirect_uri])
      query = URI.decode_www_form(uri.query || "")
      query << ["code", code]
      query << ["state", pending[:state]] if pending[:state].present?
      uri.query = URI.encode_www_form(query)

      cookies.delete(:consent_token)

      # Record authorization
      record_authorization(pending[:user][:external_id].to_i, pending[:client_id], pending[:app_name], pending[:scope], "approved")

      redirect_to uri.to_s, allow_other_host: true
    end

    # POST /oauth-provider/deny
    def deny
      consent_token = cookies[:consent_token]
      unless consent_token.present?
        return render plain: "invalid session", status: 400
      end

      pending = Rails.cache.read("consent::#{consent_token}")
      unless pending
        return render plain: "consent expired", status: 400
      end
      Rails.cache.delete("consent::#{consent_token}")

      # Record denial
      record_authorization(pending[:user][:external_id].to_i, pending[:client_id], pending[:app_name] || "", pending[:scope], "denied")

      uri = URI.parse(pending[:redirect_uri])
      query = URI.decode_www_form(uri.query || "")
      query << ["error", "access_denied"]
      query << ["error_description", "user denied the request"]
      query << ["state", pending[:state]] if pending[:state].present?
      uri.query = URI.encode_www_form(query)

      cookies.delete(:consent_token)
      redirect_to uri.to_s, allow_other_host: true
    end

    # POST /oauth-provider/token
    def token
      unless params[:grant_type] == "authorization_code"
        return render json: { error: "unsupported_grant_type", error_description: "only authorization_code is supported" }, status: 400
      end

      code = params[:code]
      unless code.present?
        return render json: { error: "invalid_request", error_description: "missing code parameter" }, status: 400
      end

      entry = Rails.cache.read("auth_code::#{code}")
      unless entry
        return render json: { error: "invalid_grant", error_description: "invalid or expired authorization code" }, status: 400
      end
      Rails.cache.delete("auth_code::#{code}")

      # Extract client credentials
      client_id, client_secret = extract_client_credentials
      client_id ||= params[:client_id]
      client_secret ||= params[:client_secret]

      # Validate client_id matches
      if client_id.present? && client_id != entry[:client_id]
        return render json: { error: "invalid_grant", error_description: "client_id mismatch" }, status: 400
      end

      # Validate redirect_uri matches
      if params[:redirect_uri].present? && params[:redirect_uri] != entry[:redirect_uri]
        return render json: { error: "invalid_grant", error_description: "redirect_uri mismatch" }, status: 400
      end

      # Validate client_secret (skip for test app)
      cid = client_id || entry[:client_id]
      unless cid == "test"
        app = find_app_by_client_id(cid)
        unless app
          return render json: { error: "invalid_client", error_description: "unknown client_id" }, status: 401
        end
        unless client_secret.present? && client_secret == app["client_secret"]
          return render json: { error: "invalid_client", error_description: "invalid client_secret" }, status: 401
        end
      end

      user = entry[:user]
      subject = user[:external_id]

      # Generate privacy email
      privacy_email = "#{user[:username]}_#{subject}@privaterelay.sparkloc.com"

      # Sign tokens
      access_token = jwt_provider.sign_access_token(issuer_url, subject, cid, entry[:scope])

      id_token = nil
      if entry[:scope].to_s.include?("openid")
        user_info = {
          id: subject,
          username: user[:username],
          name: user[:name],
          email: privacy_email,
          avatar_url: user[:avatar_url],
          trust_level: user[:trust_level],
        }
        id_token = jwt_provider.sign_id_token(issuer_url, cid, user_info, nonce: entry[:oidc_nonce])
      end

      # Cache user info for /userinfo
      cached_info = {
        id: subject,
        username: user[:username],
        name: user[:name],
        avatar_url: user[:avatar_url],
        trust_level: user[:trust_level],
        email: privacy_email,
        active: true,
        silenced: false,
      }
      Rails.cache.write("userinfo::#{subject}", cached_info, expires_in: 6.hours)

      render json: {
        access_token: access_token,
        token_type: "Bearer",
        expires_in: 1800,
        id_token: id_token,
        scope: entry[:scope],
      }.compact
    end

    # GET /oauth-provider/userinfo
    def userinfo
      token = extract_bearer_token
      unless token
        response.headers["WWW-Authenticate"] = 'Bearer error="invalid_token"'
        return render plain: "missing or invalid bearer token", status: 401
      end

      claims = jwt_provider.decode_access_token(token)
      unless claims
        response.headers["WWW-Authenticate"] = 'Bearer error="invalid_token"'
        return render plain: "invalid access token", status: 401
      end

      cached = Rails.cache.read("userinfo::#{claims["sub"]}")
      if cached
        subject = (cached[:id] || cached["id"] || claims["sub"]).to_s
        uname = cached[:username] || cached["username"]
        render json: {
          id: subject,
          sub: subject,
          username: uname,
          preferred_username: uname,
          name: cached[:name] || cached["name"],
          email: cached[:email] || cached["email"],
          email_verified: true,
          avatar_url: cached[:avatar_url] || cached["avatar_url"],
          picture: cached[:avatar_url] || cached["avatar_url"],
          trust_level: cached[:trust_level] || cached["trust_level"],
          active: true,
        }.compact
      else
        render json: { id: claims["sub"].to_s, sub: claims["sub"].to_s, active: true }
      end
    end

    # GET /oauth-provider/certs
    def certs
      render json: { keys: [jwt_provider.public_jwk] }
    end

    # GET /.well-known/openid-configuration
    def openid_configuration
      iss = issuer_url
      render json: {
        issuer: iss,
        authorization_endpoint: "#{iss}/auth",
        token_endpoint: "#{iss}/token",
        userinfo_endpoint: "#{iss}/userinfo",
        jwks_uri: "#{iss}/certs",
        response_types_supported: ["code"],
        subject_types_supported: ["public"],
        id_token_signing_alg_values_supported: ["RS256"],
        scopes_supported: ["openid", "profile", "email"],
        token_endpoint_auth_methods_supported: ["client_secret_basic", "client_secret_post"],
        claims_supported: %w[sub iss aud exp iat auth_time nonce email email_verified preferred_username name picture trust_level],
      }
    end

    # POST /oauth-provider/introspect
    def introspect
      claims = jwt_provider.decode_access_token(params[:token])
      if claims
        render json: { active: true, sub: claims["sub"], client_id: claims["client_id"], scope: claims["scope"], iss: claims["iss"], exp: claims["exp"] }
      else
        render json: { active: false }
      end
    end

    # POST /oauth-provider/revoke
    def revoke
      render json: {}, status: 200
    end

    private

    def jwt_provider
      @jwt_provider ||= ::DiscourseSparkloc::JwtProvider.new
    end

    def sso_helper
      @sso_helper ||= ::DiscourseSparkloc::SsoHelper.new(
        SiteSetting.sparkloc_discourse_sso_secret,
        Discourse.base_url,
      )
    end

    def issuer_url
      SiteSetting.respond_to?(:sparkloc_oauth2_issuer_url) && SiteSetting.sparkloc_oauth2_issuer_url.present? ?
        SiteSetting.sparkloc_oauth2_issuer_url.chomp("/") :
        "#{Discourse.base_url}/oauth-provider"
    end

    def find_app_by_client_id(client_id)
      return nil if client_id.blank?
      # Built-in test app
      if client_id == "test"
        return {
          "client_id" => "test",
          "client_secret" => "__TEST_APP_NO_SECRET__",
          "name" => "Test App (Built-in)",
          "redirect_uris" => "http://localhost:8080/,http://localhost:3000/,http://127.0.0.1:8080/,http://127.0.0.1:3000/",
          "owner_discourse_id" => 0,
        }
      end
      app = SparklocOauthApp.find_by(client_id: client_id)
      return nil unless app
      {
        "client_id" => app.client_id,
        "client_secret" => app.client_secret,
        "name" => app.name,
        "redirect_uris" => app.redirect_uris,
        "owner_discourse_id" => app.owner_discourse_id,
      }
    end

    def record_authorization(discourse_id, client_id, app_name, scope, status)
      SparklocAuthorization.create!(
        discourse_id: discourse_id,
        client_id: client_id,
        app_name: app_name || "",
        scope: scope || "openid",
        status: status,
      )
    end

    def extract_client_credentials
      auth_header = request.headers["Authorization"]
      if auth_header.present? && auth_header.start_with?("Basic ")
        decoded = Base64.decode64(auth_header.sub("Basic ", "").strip)
        parts = decoded.split(":", 2)
        return parts if parts.length == 2
      end
      [nil, nil]
    end

    def extract_bearer_token
      auth = request.headers["Authorization"]
      return nil unless auth.present? && auth.start_with?("Bearer ")
      token = auth.sub("Bearer ", "").strip
      token.present? ? token : nil
    end


    def render_consent_page(user, app_name)
      avatar = user[:avatar_url].present? ? user[:avatar_url] : "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ccircle cx='50' cy='50' r='50' fill='%23ddd'/%3E%3C/svg%3E"
      iss = issuer_url

      <<~HTML
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>授权 - #{ERB::Util.html_escape(app_name)}</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
        .card { background: #fff; border-radius: 16px; box-shadow: 0 2px 20px rgba(0,0,0,0.08); max-width: 420px; width: 100%; padding: 40px 32px; text-align: center; }
        .lock-icon { width: 48px; height: 48px; margin: 0 auto 16px; color: #666; }
        .app-name { font-size: 24px; font-weight: 700; margin-bottom: 4px; }
        .subtitle { color: #888; font-size: 14px; margin-bottom: 24px; }
        .section { background: #f9f9f9; border-radius: 12px; padding: 16px; margin-bottom: 16px; text-align: left; }
        .user-row { display: flex; align-items: center; gap: 12px; }
        .avatar { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; }
        .user-name { font-weight: 600; font-size: 15px; }
        .user-sub { color: #888; font-size: 13px; }
        .info-label { color: #888; font-size: 13px; margin-bottom: 8px; }
        .scope-row { display: flex; align-items: center; gap: 8px; font-size: 14px; color: #333; }
        .btn { display: block; width: 100%; padding: 14px; border: none; border-radius: 12px; font-size: 16px; font-weight: 600; cursor: pointer; margin-bottom: 10px; transition: opacity 0.2s; }
        .btn:hover { opacity: 0.85; }
        .btn-allow { background: #111; color: #fff; }
        .btn-deny { background: #fff; color: #333; border: 1px solid #ddd; }
        </style>
        </head>
        <body>
        <div class="card">
          <svg class="lock-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
          <div class="app-name">#{ERB::Util.html_escape(app_name)}</div>
          <div class="subtitle">请求访问你的 Sparkloc 账户</div>
          <div class="section">
            <div class="user-row">
              <img class="avatar" src="#{ERB::Util.html_escape(avatar)}" alt="avatar">
              <div>
                <div class="user-name">#{ERB::Util.html_escape(user[:name])}</div>
                <div class="user-sub">以 @#{ERB::Util.html_escape(user[:username])} 的身份授权</div>
              </div>
            </div>
          </div>
          <div class="section">
            <div class="info-label">将获取以下权限</div>
            <div class="scope-row"><span>👤</span><span>获取你的用户基本信息</span></div>
          </div>
          <form method="POST" action="#{iss}/authorize">
            <button type="submit" class="btn btn-allow">允许</button>
          </form>
          <form method="POST" action="#{iss}/deny">
            <button type="submit" class="btn btn-deny">拒绝</button>
          </form>
        </div>
        </body>
        </html>
      HTML
    end
  end
end
