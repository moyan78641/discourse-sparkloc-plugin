# frozen_string_literal: true

module ::DiscourseSparkloc
  class AppsAdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    # GET /sparkloc/admin/apps.json
    def index
      apps = load_all_apps.map do |app|
        owner = User.find_by(id: app["owner_discourse_id"])
        app.merge(
          "owner_username" => owner&.username || "unknown",
        )
      end
      render json: { apps: apps }
    end

    # PUT /sparkloc/admin/apps/:id.json
    def update
      app = load_app(params[:id])
      return render json: { error: "not found" }, status: 404 unless app

      app["name"] = params[:name] if params[:name].present?
      app["description"] = params[:description] if params.key?(:description)
      app["redirect_uris"] = params[:redirect_uris] if params[:redirect_uris].present?
      app["updated_at"] = Time.now.strftime("%Y-%m-%d %H:%M")
      save_app(params[:id], app)
      render json: app
    end

    # DELETE /sparkloc/admin/apps/:id.json
    def destroy
      app = load_app(params[:id])
      return render json: { error: "not found" }, status: 404 unless app

      PluginStore.remove(PLUGIN_NAME, "oauth2_app::#{params[:id]}")
      render json: { ok: true }
    end

    private

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

    def parse_record(raw)
      return nil if raw.nil?
      raw.is_a?(String) ? JSON.parse(raw) : raw
    rescue JSON::ParserError
      nil
    end
  end
end
