# frozen_string_literal: true

module ::DiscourseSparkloc
  class MerchantsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr
    skip_before_action :redirect_to_login_if_required

    # GET /sparkloc/merchants.json — public, no auth
    def index
      merchants = load_all_merchants
      render json: { merchants: merchants }
    end

    private

    def load_all_merchants
      rows = PluginStoreRow.where(plugin_name: PLUGIN_NAME)
                           .where("key LIKE 'merchant::%'")
                           .where.not(key: "merchant_next_id")
      rows.filter_map { |r| parse_record(r.value) }
          .sort_by { |m| [m["sort_order"].to_i, -m["id"].to_i] }
    end

    def parse_record(raw)
      return nil if raw.nil?
      raw.is_a?(String) ? JSON.parse(raw) : raw
    rescue JSON::ParserError
      nil
    end
  end
end
