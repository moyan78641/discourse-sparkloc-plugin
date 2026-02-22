# frozen_string_literal: true

module Jobs
  class CleanOldAuthorizations < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      cutoff = 7.days.ago.strftime("%Y-%m-%d %H:%M")

      PluginStoreRow.where(plugin_name: ::DiscourseSparkloc::PLUGIN_NAME)
                    .where("key LIKE 'authorization::%'")
                    .where.not(key: "authorization_next_id")
                    .each do |row|
        record = begin
          JSON.parse(row.value)
        rescue
          nil
        end
        next unless record

        created = record["created_at"]
        next unless created.present? && created < cutoff

        PluginStore.remove(::DiscourseSparkloc::PLUGIN_NAME, row.key)
      end
    end
  end
end
