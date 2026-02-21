# frozen_string_literal: true

require "net/http"
require "json"

module ::DiscourseSparkloc
  class CreemController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    # POST /sparkloc/creem/checkout
    def create_checkout
      # 检查是否已有活跃订阅
      record = load_subscription(current_user.username)
      if record && %w[active trialing].include?(record["status"])
        return render json: { error: "您已有有效订阅" }, status: 422
      end

      success_url = "#{Discourse.base_url}/u/#{current_user.username}/billing/subscriptions"

      body = {
        product_id: SiteSetting.sparkloc_creem_product_id,
        success_url: success_url,
        customer: { email: current_user.email },
        metadata: { discourse_username: current_user.username },
      }

      resp = creem_request(:post, "/v1/checkouts", body: body)

      if resp.is_a?(Net::HTTPSuccess)
        data = JSON.parse(resp.body)
        checkout_url = data["checkout_url"] || data["url"]
        render json: { checkout_url: checkout_url }
      else
        Rails.logger.error("[Creem] 创建 Checkout 失败: #{resp.code} #{resp.body}")
        render json: { error: "创建支付会话失败" }, status: 502
      end
    rescue => e
      Rails.logger.error("[Creem] 创建 Checkout 异常: #{e.message}")
      render json: { error: "支付服务暂时不可用" }, status: 502
    end

    # GET /sparkloc/creem/subscription
    def subscription_status
      record = load_subscription(current_user.username)
      if record
        render json: {
          status: record["status"],
          creem_subscription_id: record["creem_subscription_id"],
          current_period_end: record["current_period_end"],
          canceled_at: record["canceled_at"],
        }
      else
        render json: { status: "none" }
      end
    end

    # POST /sparkloc/creem/cancel
    def cancel_subscription
      record = load_subscription(current_user.username)
      unless record && record["creem_subscription_id"].present?
        return render json: { error: "没有可取消的订阅" }, status: 422
      end

      unless record["status"] == "active" || record["status"] == "trialing"
        return render json: { error: "当前订阅状态无法取消" }, status: 422
      end

      sub_id = record["creem_subscription_id"]
      resp = creem_request(:post, "/v1/subscriptions/#{sub_id}/cancel", body: { mode: "scheduled" })

      if resp.is_a?(Net::HTTPSuccess)
        render json: { success: true }
      else
        Rails.logger.error("[Creem] 取消订阅失败: #{resp.code} #{resp.body}")
        render json: { error: "取消订阅失败，请稍后重试" }, status: 502
      end
    rescue => e
      Rails.logger.error("[Creem] 取消订阅异常: #{e.message}")
      render json: { error: "服务暂时不可用" }, status: 502
    end

    # POST /sparkloc/creem/billing-portal
    def billing_portal
      record = load_subscription(current_user.username)
      unless record && record["creem_customer_id"].present?
        return render json: { error: "没有可管理的订阅" }, status: 422
      end

      resp = creem_request(:post, "/v1/customers/billing", body: { customer_id: record["creem_customer_id"] })

      if resp.is_a?(Net::HTTPSuccess)
        data = JSON.parse(resp.body)
        render json: { url: data["customer_portal_link"] }
      else
        Rails.logger.error("[Creem] 获取 billing portal 失败: #{resp.code} #{resp.body}")
        render json: { error: "无法打开账单管理页面" }, status: 502
      end
    rescue => e
      Rails.logger.error("[Creem] billing portal 异常: #{e.message}")
      render json: { error: "服务暂时不可用" }, status: 502
    end

    private

    def creem_api_base
      SiteSetting.sparkloc_creem_test_mode ? "https://test-api.creem.io" : "https://api.creem.io"
    end

    def creem_request(method, path, body: nil)
      uri = URI("#{creem_api_base}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      req = case method
            when :post then Net::HTTP::Post.new(uri)
            when :get  then Net::HTTP::Get.new(uri)
            end
      req["x-api-key"] = SiteSetting.sparkloc_creem_api_key
      req["Content-Type"] = "application/json"
      req.body = body.to_json if body

      http.request(req)
    end

    def load_subscription(username)
      key = "creem_subscription::#{username}"
      raw = PluginStore.get(PLUGIN_NAME, key)
      return nil if raw.nil?
      raw.is_a?(String) ? JSON.parse(raw) : raw
    end
  end
end
