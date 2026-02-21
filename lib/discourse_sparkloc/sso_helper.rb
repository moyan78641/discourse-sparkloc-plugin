# frozen_string_literal: true

require "openssl"
require "base64"
require "rack/utils"

module ::DiscourseSparkloc
  class SsoHelper
    def initialize(secret, discourse_server)
      @secret = secret
      @server = discourse_server.chomp("/")
    end

    def generate_sso_url(callback_url, nonce)
      payload = "nonce=#{nonce}&return_sso_url=#{callback_url}"
      b64 = Base64.strict_encode64(payload)
      sig = OpenSSL::HMAC.hexdigest("SHA256", @secret, b64)
      "#{@server}/session/sso_provider?sso=#{CGI.escape(b64)}&sig=#{sig}"
    end

    def validate_response(sso, sig, expected_nonce)
      computed = OpenSSL::HMAC.hexdigest("SHA256", @secret, sso)
      unless Rack::Utils.secure_compare(computed, sig)
        raise "invalid signature"
      end

      decoded = Base64.decode64(sso)
      params = Rack::Utils.parse_query(decoded)

      unless params["nonce"] == expected_nonce
        raise "nonce mismatch"
      end

      params
    end
  end
end
