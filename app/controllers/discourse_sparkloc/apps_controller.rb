# frozen_string_literal: true

module ::DiscourseSparkloc
  class AppsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    # GET /sparkloc/apps.json
    def index
      apps = SparklocOauthApp.where(owner_discourse_id: current_user.id).order(created_at: :desc)
      render json: { apps: apps.map { |a| serialize_app(a) } }
    end

    # POST /sparkloc/apps.json
    def create
      if params[:name].blank? || params[:redirect_uris].blank?
        return render json: { error: "名称和回调地址不能为空" }, status: 400
      end

      if SparklocOauthApp.exists?(["LOWER(name) = ?", params[:name].downcase])
        return render json: { error: "应用名称已被使用，请换一个" }, status: 400
      end

      app = SparklocOauthApp.create!(
        client_id: SecureRandom.uuid,
        client_secret: SecureRandom.uuid,
        name: params[:name],
        description: params[:description] || "",
        redirect_uris: params[:redirect_uris],
        owner_discourse_id: current_user.id,
      )

      render json: serialize_app(app, include_secret: true)
    end

    # PUT /sparkloc/apps/:id.json
    def update
      app = SparklocOauthApp.find_by(id: params[:id])
      return render json: { error: "not found" }, status: 404 unless app
      return render json: { error: "forbidden" }, status: 403 unless app.owner_discourse_id == current_user.id

      if params[:name].present? && params[:name] != app.name
        if SparklocOauthApp.where("LOWER(name) = ? AND id != ?", params[:name].downcase, app.id).exists?
          return render json: { error: "应用名称已被使用，请换一个" }, status: 400
        end
      end

      app.name = params[:name] if params[:name].present?
      app.description = params[:description] if params.key?(:description)
      app.redirect_uris = params[:redirect_uris] if params[:redirect_uris].present?
      app.save!

      render json: serialize_app(app)
    end

    # DELETE /sparkloc/apps/:id.json
    def destroy
      app = SparklocOauthApp.find_by(id: params[:id])
      return render json: { error: "not found" }, status: 404 unless app
      return render json: { error: "forbidden" }, status: 403 unless app.owner_discourse_id == current_user.id

      app.destroy!
      render json: { ok: true }
    end

    # POST /sparkloc/apps/:id/reset-secret.json
    def reset_secret
      app = SparklocOauthApp.find_by(id: params[:id])
      return render json: { error: "not found" }, status: 404 unless app
      return render json: { error: "forbidden" }, status: 403 unless app.owner_discourse_id == current_user.id

      app.update!(client_secret: SecureRandom.uuid)
      render json: { client_id: app.client_id, client_secret: app.client_secret }
    end

    # GET /sparkloc/authorizations.json
    def authorizations
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 20).to_i

      scope = SparklocAuthorization.where(discourse_id: current_user.id).order(created_at: :desc)
      total = scope.count
      records = scope.offset((page - 1) * per_page).limit(per_page)

      render json: {
        authorizations: records.map { |a| serialize_auth(a) },
        total: total,
        page: page,
        per_page: per_page,
      }
    end

    # POST /sparkloc/authorizations/:id/revoke.json
    def revoke_authorization
      auth = SparklocAuthorization.find_by(id: params[:id])
      return render json: { error: "not found" }, status: 404 unless auth
      return render json: { error: "forbidden" }, status: 403 unless auth.discourse_id == current_user.id

      auth.update!(status: "revoked")
      render json: { ok: true }
    end

    private

    def serialize_app(app, include_secret: false)
      h = {
        id: app.id,
        client_id: app.client_id,
        name: app.name,
        description: app.description,
        redirect_uris: app.redirect_uris,
        created_at: app.created_at&.strftime("%Y-%m-%d %H:%M"),
        updated_at: app.updated_at&.strftime("%Y-%m-%d %H:%M"),
      }
      h[:client_secret] = app.client_secret if include_secret
      h
    end

    def serialize_auth(auth)
      {
        id: auth.id,
        client_id: auth.client_id,
        app_name: auth.app_name,
        scope: auth.scope,
        status: auth.status,
        created_at: auth.created_at&.strftime("%Y-%m-%d %H:%M"),
      }
    end
  end
end
