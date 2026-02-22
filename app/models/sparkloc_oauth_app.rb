# frozen_string_literal: true

class SparklocOauthApp < ActiveRecord::Base
  self.table_name = "sparkloc_oauth_apps"

  validates :client_id, presence: true, uniqueness: true
  validates :client_secret, presence: true
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :redirect_uris, presence: true
  validates :owner_discourse_id, presence: true

  def allowed_redirect_uris
    redirect_uris.to_s.split(",").map(&:strip)
  end
end
