# frozen_string_literal: true

# Engine routes (upgrade progress, merchants, app management, creem)
DiscourseSparkloc::Engine.routes.draw do
  get "/upgrade-progress" => "upgrade_progress#index"
  get "/merchants" => "merchants#index"

  # Admin merchant management
  post   "/admin/merchants"     => "merchants_admin#create"
  put    "/admin/merchants/:id" => "merchants_admin#update"
  delete "/admin/merchants/:id" => "merchants_admin#destroy"

  # OAuth app management (native PluginStore)
  get    "/apps"                  => "apps#index"
  post   "/apps"                  => "apps#create"
  put    "/apps/:id"              => "apps#update"
  delete "/apps/:id"              => "apps#destroy"
  post   "/apps/:id/reset-secret" => "apps#reset_secret"
  get    "/authorizations"              => "apps#authorizations"
  post   "/authorizations/:id/revoke"   => "apps#revoke_authorization"

  # Admin OAuth app management
  get    "/admin/apps"            => "apps_admin#index"
  put    "/admin/apps/:id"        => "apps_admin#update"
  delete "/admin/apps/:id"        => "apps_admin#destroy"

  # Lottery
  get  "/lottery/topics"      => "lottery#topics"
  get  "/lottery/valid-posts"  => "lottery#valid_posts"
  post "/lottery/draw"         => "lottery#draw"
  get  "/lottery/result"       => "lottery#result"
  get  "/lottery/records"      => "lottery#records"

  # Creem subscription
  post "/webhooks/creem"      => "creem_webhook#handle"
  post "/creem/checkout"      => "creem#create_checkout"
  get  "/creem/subscription"  => "creem#subscription_status"
  post "/creem/cancel"        => "creem#cancel_subscription"
  post "/creem/billing-portal" => "creem#billing_portal"

  # Admin subscription management
  get    "/admin/subscriptions"       => "subscription_admin#index"
  post   "/admin/subscriptions"       => "subscription_admin#create"
  put    "/admin/subscriptions/renew" => "subscription_admin#renew"
  delete "/admin/subscriptions"       => "subscription_admin#cancel"
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
  get "/oauth-apps-admin" => "list#latest"
  get "/lottery" => "list#latest"
  get "/subscription-admin" => "list#latest", constraints: ->(req) { !req.path.end_with?(".json") }

  # User billing tab — Ember shell for direct URL access
  get "/u/:username/billing" => "users#show"
  get "/u/:username/billing/subscriptions" => "users#show"
end

# OAuth2/OIDC endpoints — native Ruby implementation
Discourse::Application.routes.draw do
  scope module: "discourse_sparkloc" do
    get  "/oauth-provider/auth"       => "oauth2#auth"
    get  "/oauth-provider/callback"   => "oauth2#callback"
    post "/oauth-provider/authorize"  => "oauth2#authorize_user"
    post "/oauth-provider/deny"       => "oauth2#deny"
    post "/oauth-provider/token"      => "oauth2#token"
    get  "/oauth-provider/userinfo"   => "oauth2#userinfo"
    get  "/oauth-provider/certs"      => "oauth2#certs"
    post "/oauth-provider/introspect" => "oauth2#introspect"
    post "/oauth-provider/revoke"     => "oauth2#revoke"

    # OIDC discovery document
    get "/oauth-provider/.well-known/openid-configuration" => "oauth2#openid_configuration"
  end
end
