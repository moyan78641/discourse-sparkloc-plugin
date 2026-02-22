# frozen_string_literal: true

module Jobs
  class CheckCanceledSubscriptions < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.sparkloc_creem_enabled

      group = Group.find_by(name: SiteSetting.sparkloc_creem_group_name)
      unless group
        Rails.logger.error("[Creem] 定时任务: 群组 '#{SiteSetting.sparkloc_creem_group_name}' 不存在")
        return
      end

      rows = PluginStoreRow.where(
        plugin_name: DiscourseSparkloc::PLUGIN_NAME,
      ).where("key LIKE ?", "creem_subscription::%")

      rows.each do |row|
        begin
          record = row.value.is_a?(String) ? JSON.parse(row.value) : row.value
          next if record["current_period_end"].blank?

          status = record["status"]
          period_end = Time.parse(record["current_period_end"])

          # 处理已取消的订阅：到期后移出群组
          # 处理手动订阅：到期后自动过期
          should_expire = false
          if status == "canceled" && period_end <= Time.now
            should_expire = true
          elsif status == "active" && record["source"] == "manual" && period_end <= Time.now
            should_expire = true
          end

          next unless should_expire

          username = row.key.sub("creem_subscription::", "")
          user = User.find_by(username: username)

          if user
            group.remove(user)
            Rails.logger.info("[Creem] 定时任务: 用户 #{username} 订阅已到期，已移出群组")
          end

          record["status"] = "expired"
          record["updated_at"] = Time.now.iso8601
          PluginStore.set(DiscourseSparkloc::PLUGIN_NAME, row.key, record.to_json)
        rescue => e
          Rails.logger.error("[Creem] 定时任务处理 #{row.key} 出错: #{e.message}")
        end
      end
    end
  end
end
