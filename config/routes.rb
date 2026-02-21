# frozen_string_literal: true

# Engine routes (upgrade progress, merchants JSON, app management proxy)
DiscourseSparkloc::Engine.routes.draw do
  get "/upgrade-progress" => "upgrade_progress#index"
  get "/merchants" => "merchants#index"

  # Admin merchant management
  post   "/admin/merchants"     => "merchants_admin#create"
  put    "/admin/merchants/:id" => "merchants_admin#update"
  delete "/admin/merchants/:id" => "merchants_admin#destroy"

  # OAuth app management proxy (user-facing, Bearer token auth)
  get    "/apps"                  => "apps#index"
  post   "/apps"                  => "apps#create"
  put    "/apps/:id"              => "apps#update"
  delete "/apps/:id"              => "apps#destroy"
  post   "/apps/:id/reset-secret" => "apps#reset_secret"
  get    "/authorizations"              => "apps#authorizations"
  post   "/authorizations/:id/revoke"   => "apps#revoke_authorization"
end

# Mount engine at /sparkloc
Discourse::Application.routes.draw do
  mount ::DiscourseSparkloc::Engine, at: "/sparkloc"
end

# Top-level Ember page routes — Rails must serve the Ember shell for these
# so that direct browser navigation (not Ember transition) works.
Discourse::Application.routes.draw do
  # These render the Ember app; Ember router then takes over client-side.
  get "/merchants" => "list#latest"
  get "/oauth-apps" => "list#latest"
end

# OAuth2 proxy routes — directly on root, no engine prefix
Discourse::Application.routes.draw do
  scope module: "discourse_sparkloc" do
    get  "/oauth-provider/auth"       => "oauth_proxy#auth"
    get  "/oauth-provider/callback"   => "oauth_proxy#callback"
    post "/oauth-provider/authorize"  => "oauth_proxy#authorize_user"
    post "/oauth-provider/deny"       => "oauth_proxy#deny"
    post "/oauth-provider/token"      => "oauth_proxy#token"
    get  "/oauth-provider/userinfo"   => "oauth_proxy#userinfo"
    get  "/oauth-provider/certs"      => "oauth_proxy#certs"
    post "/oauth-provider/introspect" => "oauth_proxy#introspect"
    post "/oauth-provider/revoke"     => "oauth_proxy#revoke"

    # OIDC discovery document
    get "/.well-known/openid-configuration" => "oauth_proxy#openid_configuration"
  end
end
