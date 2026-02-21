# frozen_string_literal: true

module ::DiscourseSparkloc
  class MerchantsAdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    # POST /sparkloc/admin/merchants.json
    def create
      unless params[:name].present?
        return render json: { error: "商家名称不能为空" }, status: 400
      end

      id = next_id("merchant_next_id")
      merchant = {
        "id" => id,
        "name" => params[:name],
        "logo_url" => params[:logo_url] || "",
        "website" => params[:website] || "",
        "discourse_username" => params[:discourse_username] || "",
        "description" => params[:description] || "",
        "sort_order" => (params[:sort_order] || 0).to_i,
        "created_at" => Time.now.iso8601,
        "updated_at" => Time.now.iso8601,
      }
      save_merchant(id, merchant)
      render json: merchant
    end

    # PUT /sparkloc/admin/merchants/:id.json
    def update
      merchant = load_merchant(params[:id])
      return render json: { error: "not found" }, status: 404 unless merchant

      merchant["name"] = params[:name] if params[:name].present?
      merchant["logo_url"] = params[:logo_url] if params.key?(:logo_url)
      merchant["website"] = params[:website] if params.key?(:website)
      merchant["discourse_username"] = params[:discourse_username] if params.key?(:discourse_username)
      merchant["description"] = params[:description] if params.key?(:description)
      merchant["sort_order"] = params[:sort_order].to_i if params.key?(:sort_order)
      merchant["updated_at"] = Time.now.iso8601

      save_merchant(params[:id], merchant)
      render json: merchant
    end

    # DELETE /sparkloc/admin/merchants/:id.json
    def destroy
      merchant = load_merchant(params[:id])
      return render json: { error: "not found" }, status: 404 unless merchant

      PluginStore.remove(PLUGIN_NAME, "merchant::#{params[:id]}")
      render json: { ok: true }
    end

    private

    def next_id(key)
      current = PluginStore.get(PLUGIN_NAME, key).to_i
      new_id = current + 1
      PluginStore.set(PLUGIN_NAME, key, new_id)
      new_id
    end

    def load_merchant(id)
      raw = PluginStore.get(PLUGIN_NAME, "merchant::#{id}")
      parse_record(raw)
    end

    def save_merchant(id, data)
      PluginStore.set(PLUGIN_NAME, "merchant::#{id}", data.to_json)
    end

    def parse_record(raw)
      return nil if raw.nil?
      raw.is_a?(String) ? JSON.parse(raw) : raw
    rescue JSON::ParserError
      nil
    end
  end
end
