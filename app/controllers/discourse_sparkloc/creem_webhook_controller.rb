# frozen_string_literal: true

module ::DiscourseSparkloc
  class CreemWebhookController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required

    def handle
      unless SiteSetting.sparkloc_creem_enabled
        return render json: { error: "not found" }, status: 404
      end

      raw_body = request.body.read
      signature = request.headers["creem-signature"]

      unless verify_signature(raw_body, signature)
        Rails.logger.warn("[Creem] Webhook 签名验证失败, IP: #{request.remote_ip}")
        return render json: { error: "invalid signature" }, status: 401
      end

      begin
        payload = JSON.parse(raw_body)
      rescue JSON::ParserError => e
        Rails.logger.error("[Creem] Webhook JSON 解析失败: #{e.message}")
        return render json: { error: "invalid json" }, status: 400
      end

      event_type = payload["eventType"]
      object = payload["object"]

      Rails.logger.info("[Creem] 收到 Webhook: #{event_type}")

      case event_type
      when "checkout.completed"
        handle_checkout_completed(object)
      when "subscription.active"
        handle_subscription_active(object)
      when "subscription.paid"
        handle_subscription_paid(object)
      when "subscription.trialing"
        handle_subscription_trialing(object)
      when "subscription.canceled"
        handle_subscription_canceled(object)
      when "subscription.expired"
        handle_subscription_expired(object)
      when "subscription.paused"
        handle_subscription_paused(object)
      when "refund.created"
        handle_refund_created(object)
      else
        Rails.logger.info("[Creem] 未处理的事件类型: #{event_type}")
      end

      render json: { received: true }, status: 200
    end

    private

    def verify_signature(raw_body, signature)
      return false if signature.blank?
      secret = SiteSetting.sparkloc_creem_webhook_secret
      return true if secret.blank? # 未配置密钥时跳过验证
      computed = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
      Rack::Utils.secure_compare(computed, signature)
    end

    # === 激活类事件 ===

    def handle_checkout_completed(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "active")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] checkout.completed: 用户 #{user.username} 已加入群组")
    end

    def handle_subscription_active(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "active")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] subscription.active: 用户 #{user.username}")
    end

    def handle_subscription_paid(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "active")
      save_subscription(user.username, sub_data)
      Rails.logger.info("[Creem] subscription.paid: 用户 #{user.username}, period_end: #{sub_data["current_period_end"]}")
    end

    def handle_subscription_trialing(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "trialing")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] subscription.trialing: 用户 #{user.username}")
    end

    # === 终止类事件 ===

    def handle_subscription_canceled(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "canceled")
      sub_data["canceled_at"] = object["canceled_at"] || Time.now.iso8601
      save_subscription(user.username, sub_data)
      # 不移除群组，等定时任务在 current_period_end 后处理
      Rails.logger.info("[Creem] subscription.canceled: 用户 #{user.username}, period_end: #{sub_data["current_period_end"]}")
    end

    def handle_subscription_expired(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "expired")
      save_subscription(user.username, sub_data)
      remove_user_from_group(user)
      Rails.logger.info("[Creem] subscription.expired: 用户 #{user.username} 已移出群组")
    end

    def handle_subscription_paused(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "paused")
      save_subscription(user.username, sub_data)
      remove_user_from_group(user)
      Rails.logger.info("[Creem] subscription.paused: 用户 #{user.username} 已移出群组")
    end

    def handle_refund_created(object)
      user = find_user_from_event(object)
      return unless user

      save_subscription(user.username, { "status" => "refunded" })
      remove_user_from_group(user)
      Rails.logger.info("[Creem] refund.created: 用户 #{user.username} 已移出群组")
    end

    # === 辅助方法 ===

    def find_user_from_event(object)
      # 优先从 metadata.discourse_username 查找
      username = nil
      if object.is_a?(Hash)
        metadata = object.dig("metadata") || object.dig("subscription", "metadata") || {}
        username = metadata["discourse_username"]
      end

      if username.present?
        user = User.find_by(username: username)
        if user.nil?
          Rails.logger.warn("[Creem] 用户名 #{username} 不存在")
        end
        return user
      end

      # fallback: 从 customer.email 查找
      email = object.dig("customer", "email")
      if email.present?
        user = User.find_by_email(email)
        if user.nil?
          Rails.logger.warn("[Creem] 邮箱 #{email} 对应的用户不存在")
        end
        return user
      end

      Rails.logger.warn("[Creem] 事件中无法提取用户信息")
      nil
    end

    def extract_subscription_data(object, status)
      data = { "status" => status }

      # 提取 subscription id
      sub_id = object.dig("subscription", "id") || object["id"]
      data["creem_subscription_id"] = sub_id if sub_id.present?

      # 提取 customer id
      cust_id = object.dig("customer", "id")
      data["creem_customer_id"] = cust_id if cust_id.present?

      # 提取 product id
      prod_id = object.dig("product", "id")
      data["product_id"] = prod_id if prod_id.present?

      # 提取 period end
      period_end = object["current_period_end_date"] || object.dig("subscription", "current_period_end_date")
      data["current_period_end"] = period_end if period_end.present?

      data
    end

    def add_user_to_group(user)
      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      if group.nil?
        Rails.logger.error("[Creem] 群组 '#{SiteSetting.sparkloc_creem_group_name}' 不存在")
        return
      end
      group.add(user) unless group.users.include?(user)
    end

    def remove_user_from_group(user)
      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      if group.nil?
        Rails.logger.error("[Creem] 群组 '#{SiteSetting.sparkloc_creem_group_name}' 不存在")
        return
      end
      group.remove(user)
    end

    def save_subscription(username, attrs)
      key = "creem_subscription::#{username}"
      existing_json = PluginStore.get(PLUGIN_NAME, key)
      record = existing_json.is_a?(String) ? JSON.parse(existing_json) : (existing_json || {})
      record.merge!(attrs)
      record["updated_at"] = Time.now.iso8601
      record["created_at"] ||= Time.now.iso8601
      PluginStore.set(PLUGIN_NAME, key, record.to_json)
    end
  end
end
