# frozen_string_literal: true

module ::DiscourseSparkloc
  class AppsAdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    # GET /sparkloc/admin/apps.json
    def index
      apps = SparklocOauthApp.order(created_at: :desc).map do |app|
        owner = User.find_by(id: app.owner_discourse_id)
        {
          id: app.id,
          client_id: app.client_id,
          name: app.name,
          description: app.description,
          redirect_uris: app.redirect_uris,
          owner_discourse_id: app.owner_discourse_id,
          owner_username: owner&.username || "unknown",
          created_at: app.created_at&.strftime("%Y-%m-%d %H:%M"),
          updated_at: app.updated_at&.strftime("%Y-%m-%d %H:%M"),
        }
      end
      render json: { apps: apps }
    end

    # PUT /sparkloc/admin/apps/:id.json
    def update
      app = SparklocOauthApp.find_by(id: params[:id])
      return render json: { error: "not found" }, status: 404 unless app

      app.name = params[:name] if params[:name].present?
      app.description = params[:description] if params.key?(:description)
      app.redirect_uris = params[:redirect_uris] if params[:redirect_uris].present?
      app.save!

      render json: {
        id: app.id,
        client_id: app.client_id,
        name: app.name,
        description: app.description,
        redirect_uris: app.redirect_uris,
        updated_at: app.updated_at&.strftime("%Y-%m-%d %H:%M"),
      }
    end

    # DELETE /sparkloc/admin/apps/:id.json
    def destroy
      app = SparklocOauthApp.find_by(id: params[:id])
      return render json: { error: "not found" }, status: 404 unless app

      app.destroy!
      render json: { ok: true }
    end
  end
end
