# frozen_string_literal: true

module ::DiscourseSparkloc
  class SubscriptionAdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_admin

    # GET /sparkloc/admin/subscriptions.json — 列出所有手动订阅
    def index
      # 从 PluginStore 获取所有订阅记录
      rows = PluginStoreRow.where(plugin_name: PLUGIN_NAME)
                           .where("key LIKE 'creem_subscription::%'")
      subs = rows.filter_map do |row|
        username = row.key.sub("creem_subscription::", "")
        data = row.value.is_a?(String) ? JSON.parse(row.value) : row.value
        next if data["status"] == "none"
        user = User.find_by(username: username)
        {
          username: username,
          user_id: user&.id,
          status: data["status"],
          source: data["source"] || "creem",
          current_period_end: data["current_period_end"],
          created_at: data["created_at"],
          updated_at: data["updated_at"],
        }
      rescue
        nil
      end
      render json: { subscriptions: subs }
    end

    # POST /sparkloc/admin/subscriptions.json — 手动添加订阅
    def create
      username = params[:username]
      months = (params[:months] || 1).to_i
      return render json: { error: "请填写用户名" }, status: 400 if username.blank?
      return render json: { error: "月数必须大于0" }, status: 400 if months <= 0

      user = User.find_by(username: username)
      return render json: { error: "用户不存在" }, status: 404 unless user

      key = "creem_subscription::#{username}"
      existing = PluginStore.get(PLUGIN_NAME, key)
      record = if existing.is_a?(String)
                 JSON.parse(existing) rescue {}
               else
                 existing || {}
               end

      # 如果已有活跃订阅，在现有到期时间基础上续费
      period_end = if record["status"] == "active" && record["current_period_end"].present?
                     Time.parse(record["current_period_end"])
                   else
                     Time.current
                   end
      new_period_end = period_end + months.months

      record.merge!(
        "status" => "active",
        "source" => "manual",
        "current_period_end" => new_period_end.iso8601,
        "updated_at" => Time.now.iso8601,
        "created_at" => record["created_at"] || Time.now.iso8601,
        "manual_by" => current_user.username,
      )

      PluginStore.set(PLUGIN_NAME, key, record.to_json)

      # 加入群组
      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      if group
        group.add(user) unless group.users.include?(user)
      end

      render json: { success: true, username: username, period_end: new_period_end.iso8601 }
    end

    # PUT /sparkloc/admin/subscriptions/renew.json — 续费
    def renew
      username = params[:username]
      months = (params[:months] || 1).to_i
      return render json: { error: "请填写用户名" }, status: 400 if username.blank?

      user = User.find_by(username: username)
      return render json: { error: "用户不存在" }, status: 404 unless user

      key = "creem_subscription::#{username}"
      existing = PluginStore.get(PLUGIN_NAME, key)
      return render json: { error: "该用户没有订阅记录" }, status: 404 if existing.nil?

      record = existing.is_a?(String) ? JSON.parse(existing) : existing

      period_end = if record["current_period_end"].present?
                     [Time.parse(record["current_period_end"]), Time.current].max
                   else
                     Time.current
                   end
      new_period_end = period_end + months.months

      record.merge!(
        "status" => "active",
        "current_period_end" => new_period_end.iso8601,
        "updated_at" => Time.now.iso8601,
        "manual_by" => current_user.username,
      )

      PluginStore.set(PLUGIN_NAME, key, record.to_json)

      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      group&.add(user) unless group&.users&.include?(user)

      render json: { success: true, username: username, period_end: new_period_end.iso8601 }
    end

    # DELETE /sparkloc/admin/subscriptions.json — 取消订阅
    def cancel
      username = params[:username]
      return render json: { error: "请填写用户名" }, status: 400 if username.blank?

      user = User.find_by(username: username)
      return render json: { error: "用户不存在" }, status: 404 unless user

      key = "creem_subscription::#{username}"
      existing = PluginStore.get(PLUGIN_NAME, key)
      return render json: { error: "该用户没有订阅记录" }, status: 404 if existing.nil?

      record = existing.is_a?(String) ? JSON.parse(existing) : existing
      record.merge!(
        "status" => "canceled",
        "canceled_at" => Time.now.iso8601,
        "updated_at" => Time.now.iso8601,
        "manual_by" => current_user.username,
      )
      PluginStore.set(PLUGIN_NAME, key, record.to_json)

      # 移出群组
      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      group&.remove(user)

      render json: { success: true }
    end

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end
