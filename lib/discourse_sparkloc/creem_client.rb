# frozen_string_literal: true

require "json"
require "net/http"

module ::DiscourseSparkloc
  module CreemClient
    module_function

    def api_base
      SiteSetting.sparkloc_creem_test_mode ? "https://test-api.creem.io" : "https://api.creem.io"
    end

    def request(method, path, body: nil, query: nil)
      uri = URI("#{api_base}#{path}")
      uri.query = URI.encode_www_form(query) if query.present?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      req = case method
            when :post then Net::HTTP::Post.new(uri)
            when :get then Net::HTTP::Get.new(uri)
            else
              raise ArgumentError, "unsupported method: #{method}"
            end

      req["x-api-key"] = SiteSetting.sparkloc_creem_api_key
      req["Content-Type"] = "application/json"
      req.body = body.to_json if body

      http.request(req)
    end

    def create_checkout(body)
      request(:post, "/v1/checkouts", body: body)
    end

    def fetch_subscription(subscription_id)
      request(:get, "/v1/subscriptions", query: { subscription_id: subscription_id })
    end

    def cancel_subscription(subscription_id, mode: "scheduled")
      request(:post, "/v1/subscriptions/#{subscription_id}/cancel", body: { mode: mode })
    end

    def billing_portal(customer_id)
      request(:post, "/v1/customers/billing", body: { customer_id: customer_id })
    end

    def parse_json(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      nil
    end

    def extract_subscription_attrs(payload)
      return {} unless payload.is_a?(Hash)

      attrs = {
        "status" => payload["status"],
        "creem_subscription_id" => payload["id"],
        "current_period_end" => payload["current_period_end_date"],
        "canceled_at" => payload["canceled_at"],
        "source" => "creem",
      }

      customer_id = payload.dig("customer", "id")
      product_id = payload.dig("product", "id")
      attrs["creem_customer_id"] = customer_id if customer_id.present?
      attrs["product_id"] = product_id if product_id.present?

      attrs.compact
    end
  end
end
