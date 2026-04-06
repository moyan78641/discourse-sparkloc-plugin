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
        Rails.logger.warn("[Creem] Webhook signature verification failed, IP: #{request.remote_ip}")
        return render json: { error: "invalid signature" }, status: 401
      end

      payload = JSON.parse(raw_body)
      event_type = payload["eventType"]
      object = payload["object"]

      Rails.logger.info("[Creem] Webhook received: #{event_type}")

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
      when "subscription.scheduled_cancel"
        handle_subscription_scheduled_cancel(object)
      when "subscription.expired"
        handle_subscription_expired(object)
      when "subscription.paused"
        handle_subscription_paused(object)
      when "refund.created"
        handle_refund_created(object)
      else
        Rails.logger.info("[Creem] Unhandled event type: #{event_type}")
      end

      render json: { received: true }, status: 200
    rescue JSON::ParserError => e
      Rails.logger.error("[Creem] Webhook JSON parse failed: #{e.message}")
      render json: { error: "invalid json" }, status: 400
    end

    private

    def verify_signature(raw_body, signature)
      return false if signature.blank?

      secret = SiteSetting.sparkloc_creem_webhook_secret
      return true if secret.blank?

      computed = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
      Rack::Utils.secure_compare(computed, signature)
    end

    def handle_checkout_completed(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "active")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] checkout.completed: #{user.username} added to group")
    end

    def handle_subscription_active(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "active")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] subscription.active: #{user.username}")
    end

    def handle_subscription_paid(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "active")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] subscription.paid: #{user.username}, period_end=#{sub_data["current_period_end"]}")
    end

    def handle_subscription_trialing(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "trialing")
      save_subscription(user.username, sub_data)
      add_user_to_group(user)
      Rails.logger.info("[Creem] subscription.trialing: #{user.username}")
    end

    def handle_subscription_canceled(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "canceled")
      sub_data["canceled_at"] = object["canceled_at"] || Time.current.iso8601
      save_subscription(user.username, sub_data)
      Rails.logger.info("[Creem] subscription.canceled: #{user.username}, period_end=#{sub_data["current_period_end"]}")
    end

    def handle_subscription_scheduled_cancel(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "canceled")
      sub_data["canceled_at"] = object["canceled_at"] || Time.current.iso8601
      save_subscription(user.username, sub_data)
      Rails.logger.info("[Creem] subscription.scheduled_cancel: #{user.username}, period_end=#{sub_data["current_period_end"]}")
    end

    def handle_subscription_expired(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "expired")
      save_subscription(user.username, sub_data)
      remove_user_from_group(user)
      Rails.logger.info("[Creem] subscription.expired: #{user.username} removed from group")
    end

    def handle_subscription_paused(object)
      user = find_user_from_event(object)
      return unless user

      sub_data = extract_subscription_data(object, "paused")
      save_subscription(user.username, sub_data)
      remove_user_from_group(user)
      Rails.logger.info("[Creem] subscription.paused: #{user.username} removed from group")
    end

    def handle_refund_created(object)
      user = find_user_from_event(object)
      return unless user

      save_subscription(user.username, { "status" => "refunded" })
      remove_user_from_group(user)
      Rails.logger.info("[Creem] refund.created: #{user.username} removed from group")
    end

    def find_user_from_event(object)
      username = nil
      if object.is_a?(Hash)
        metadata = object.dig("metadata") || object.dig("subscription", "metadata") || {}
        username = metadata["discourse_username"]
      end

      if username.present?
        user = User.find_by(username: username)
        Rails.logger.warn("[Creem] Unknown username from webhook: #{username}") if user.nil?
        return user
      end

      email = object.dig("customer", "email")
      if email.present?
        user = User.find_by_email(email)
        Rails.logger.warn("[Creem] No user found for webhook email: #{email}") if user.nil?
        return user
      end

      Rails.logger.warn("[Creem] Could not resolve user from webhook payload")
      nil
    end

    def extract_subscription_data(object, status)
      data = { "status" => status, "source" => "creem" }

      sub_id = object.dig("subscription", "id") || object["id"]
      customer_id = object.dig("customer", "id")
      product_id = object.dig("product", "id")
      period_end = object["current_period_end_date"] || object.dig("subscription", "current_period_end_date")

      data["creem_subscription_id"] = sub_id if sub_id.present?
      data["creem_customer_id"] = customer_id if customer_id.present?
      data["product_id"] = product_id if product_id.present?
      data["current_period_end"] = period_end if period_end.present?

      data
    end

    def add_user_to_group(user)
      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      unless group
        Rails.logger.error("[Creem] Group '#{SiteSetting.sparkloc_creem_group_name}' does not exist")
        return
      end

      group.add(user) unless group.users.include?(user)
    end

    def remove_user_from_group(user)
      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      unless group
        Rails.logger.error("[Creem] Group '#{SiteSetting.sparkloc_creem_group_name}' does not exist")
        return
      end

      group.remove(user)
    end

    def save_subscription(username, attrs)
      key = "creem_subscription::#{username}"
      existing_json = PluginStore.get(PLUGIN_NAME, key)
      record = existing_json.is_a?(String) ? JSON.parse(existing_json) : (existing_json || {})
      record.merge!(attrs)
      record["updated_at"] = Time.current.iso8601
      record["created_at"] ||= Time.current.iso8601
      PluginStore.set(PLUGIN_NAME, key, record.to_json)
    end
  end
end
