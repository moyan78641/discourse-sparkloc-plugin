# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ::DiscourseSparkloc
  class DeeplxController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    # GET /sparkloc/deeplx/key.json — get current user's API key
    def show
      result = deeplx_request(:get, "/admin/keys/show?user_id=#{current_user.id}")
      if result[:status] == 200
        render json: result[:body]
      elsif result[:status] == 404
        render json: { key: nil }
      else
        render json: { error: result[:body]["error"] || "请求失败" }, status: result[:status]
      end
    end

    # POST /sparkloc/deeplx/key/init.json — initialize API key
    def init
      result = deeplx_request(:post, "/admin/keys/init", {
        user_id: current_user.id,
        username: current_user.username,
      })
      if result[:status] == 200
        render json: result[:body]
      else
        render json: { error: result[:body]["error"] || "初始化失败" }, status: result[:status]
      end
    end

    # POST /sparkloc/deeplx/key/reset.json — reset API key
    def reset
      result = deeplx_request(:post, "/admin/keys/reset", {
        user_id: current_user.id,
      })
      if result[:status] == 200
        render json: result[:body]
      else
        render json: { error: result[:body]["error"] || "重置失败" }, status: result[:status]
      end
    end

    private

    def deeplx_request(method, path, body = nil)
      base = SiteSetting.sparkloc_deeplx_api_url.chomp("/")
      token = SiteSetting.sparkloc_deeplx_admin_token
      uri = URI.parse("#{base}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10

      if method == :get
        req = Net::HTTP::Get.new(uri)
      else
        req = Net::HTTP::Post.new(uri)
        req.body = body.to_json if body
      end

      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{token}"

      resp = http.request(req)
      parsed = begin
        JSON.parse(resp.body)
      rescue
        { "error" => resp.body }
      end

      { status: resp.code.to_i, body: parsed }
    rescue => e
      Rails.logger.error("DeepLX request failed: #{e.message}")
      { status: 502, body: { "error" => "无法连接翻译服务" } }
    end
  end
end
