# frozen_string_literal: true

require "openssl"
require "jwt"
require "base64"
require "digest"

module ::DiscourseSparkloc
  class JwtProvider
    PLUGIN_NAME = "discourse-sparkloc-plugin"
    KEY_STORE_KEY = "rsa_private_key_pem"

    def initialize
      @private_key = load_or_generate_key
      @kid = compute_kid
    end

    def sign_access_token(issuer, subject, client_id, scope)
      payload = {
        iss: issuer,
        sub: subject,
        aud: [client_id],
        exp: 30.minutes.from_now.to_i,
        iat: Time.now.to_i,
        scope: scope,
        client_id: client_id,
      }
      JWT.encode(payload, @private_key, "RS256", { kid: @kid })
    end

    def sign_id_token(issuer, client_id, user_info, nonce: nil)
      payload = {
        iss: issuer,
        sub: user_info[:id],
        aud: [client_id],
        exp: 6.hours.from_now.to_i,
        iat: Time.now.to_i,
        auth_time: Time.now.to_i,
        nonce: nonce,
        email: user_info[:email],
        email_verified: true,
        preferred_username: user_info[:username],
        name: user_info[:name],
        picture: user_info[:avatar_url],
        trust_level: user_info[:trust_level],
      }.compact
      JWT.encode(payload, @private_key, "RS256", { kid: @kid })
    end

    def decode_access_token(token)
      JWT.decode(token, @private_key.public_key, true, { algorithms: ["RS256"] }).first
    rescue JWT::DecodeError => e
      nil
    end

    def public_jwk
      pub = @private_key.public_key
      {
        kty: "RSA",
        alg: "RS256",
        use: "sig",
        kid: @kid,
        n: base64url_encode(pub.params["n"].to_s(2)),
        e: base64url_encode(pub.params["e"].to_s(2)),
      }
    end

    def kid
      @kid
    end

    private

    def load_or_generate_key
      pem = PluginStore.get(PLUGIN_NAME, KEY_STORE_KEY)
      if pem.present?
        OpenSSL::PKey::RSA.new(pem)
      else
        key = OpenSSL::PKey::RSA.generate(2048)
        PluginStore.set(PLUGIN_NAME, KEY_STORE_KEY, key.to_pem)
        key
      end
    end

    def compute_kid
      der = @private_key.public_key.to_der
      Digest::SHA256.hexdigest(der)[0..15]
    end

    def base64url_encode(data)
      Base64.urlsafe_encode64(data, padding: false)
    end
  end
end
