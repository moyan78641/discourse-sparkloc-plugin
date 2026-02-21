# frozen_string_literal: true

# Engine routes (upgrade progress, merchants)
DiscourseSparkloc::Engine.routes.draw do
  get "/upgrade-progress" => "upgrade_progress#index"
  get "/merchants" => "merchants#index"

  # Admin merchant management
  post   "/admin/merchants"     => "merchants_admin#create"
  put    "/admin/merchants/:id" => "merchants_admin#update"
  delete "/admin/merchants/:id" => "merchants_admin#destroy"
end

# Mount engine
Discourse::Application.routes.draw do
  mount ::DiscourseSparkloc::Engine, at: "/sparkloc"
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
