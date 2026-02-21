# frozen_string_literal: true

module ::DiscourseSparkloc
  class AppsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    # GET /sparkloc/apps.json
    def index
      apps = load_all_apps.select { |a| a["owner_discourse_id"] == current_user.id }
      render json: { apps: apps }
    end

    # POST /sparkloc/apps.json
    def create
      if params[:name].blank? || params[:redirect_uris].blank?
        return render json: { error: "名称和回调地址不能为空" }, status: 400
      end

      id = next_id("oauth2_app_next_id")
      client_id = SecureRandom.uuid
      client_secret = SecureRandom.uuid
      now = Time.now.strftime("%Y-%m-%d %H:%M")

      app = {
        "id" => id,
        "client_id" => client_id,
        "client_secret" => client_secret,
        "name" => params[:name],
        "redirect_uris" => params[:redirect_uris],
        "owner_discourse_id" => current_user.id,
        "created_at" => now,
        "updated_at" => now,
      }
      save_app(id, app)
      render json: { id: id, client_id: client_id, client_secret: client_secret, name: params[:name], redirect_uris: params[:redirect_uris] }
    end

    # PUT /sparkloc/apps/:id.json
    def update
      app = load_app(params[:id])
      return render json: { error: "not found" }, status: 404 unless app
      return render json: { error: "forbidden" }, status: 403 unless app["owner_discourse_id"] == current_user.id

      app["name"] = params[:name] if params[:name].present?
      app["redirect_uris"] = params[:redirect_uris] if params[:redirect_uris].present?
      app["updated_at"] = Time.now.strftime("%Y-%m-%d %H:%M")
      save_app(params[:id], app)
      render json: { id: app["id"], client_id: app["client_id"], name: app["name"], redirect_uris: app["redirect_uris"] }
    end

    # DELETE /sparkloc/apps/:id.json
    def destroy
      app = load_app(params[:id])
      return render json: { error: "not found" }, status: 404 unless app
      return render json: { error: "forbidden" }, status: 403 unless app["owner_discourse_id"] == current_user.id

      PluginStore.remove(PLUGIN_NAME, "oauth2_app::#{params[:id]}")
      render json: { ok: true }
    end

    # POST /sparkloc/apps/:id/reset-secret.json
    def reset_secret
      app = load_app(params[:id])
      return render json: { error: "not found" }, status: 404 unless app
      return render json: { error: "forbidden" }, status: 403 unless app["owner_discourse_id"] == current_user.id

      new_secret = SecureRandom.uuid
      app["client_secret"] = new_secret
      app["updated_at"] = Time.now.strftime("%Y-%m-%d %H:%M")
      save_app(params[:id], app)
      render json: { client_id: app["client_id"], client_secret: new_secret }
    end

    # GET /sparkloc/authorizations.json
    def authorizations
      auths = load_all_authorizations.select { |a| a["discourse_id"] == current_user.id }
      render json: { authorizations: auths }
    end

    # POST /sparkloc/authorizations/:id/revoke.json
    def revoke_authorization
      auth = load_authorization(params[:id])
      return render json: { error: "not found" }, status: 404 unless auth
      return render json: { error: "forbidden" }, status: 403 unless auth["discourse_id"] == current_user.id

      auth["status"] = "revoked"
      save_authorization(params[:id], auth)
      render json: { ok: true }
    end

    private

    def next_id(key)
      current = PluginStore.get(PLUGIN_NAME, key).to_i
      new_id = current + 1
      PluginStore.set(PLUGIN_NAME, key, new_id)
      new_id
    end

    def load_app(id)
      parse_record(PluginStore.get(PLUGIN_NAME, "oauth2_app::#{id}"))
    end

    def save_app(id, data)
      PluginStore.set(PLUGIN_NAME, "oauth2_app::#{id}", data.to_json)
    end

    def load_all_apps
      PluginStoreRow.where(plugin_name: PLUGIN_NAME)
                    .where("key LIKE 'oauth2\\_app::%'")
                    .where.not(key: "oauth2_app_next_id")
                    .filter_map { |r| parse_record(r.value) }
    end

    def load_authorization(id)
      parse_record(PluginStore.get(PLUGIN_NAME, "authorization::#{id}"))
    end

    def save_authorization(id, data)
      PluginStore.set(PLUGIN_NAME, "authorization::#{id}", data.to_json)
    end

    def load_all_authorizations
      PluginStoreRow.where(plugin_name: PLUGIN_NAME)
                    .where("key LIKE 'authorization::%'")
                    .where.not(key: "authorization_next_id")
                    .filter_map { |r| parse_record(r.value) }
    end

    def parse_record(raw)
      return nil if raw.nil?
      raw.is_a?(String) ? JSON.parse(raw) : raw
    rescue JSON::ParserError
      nil
    end
  end
end
