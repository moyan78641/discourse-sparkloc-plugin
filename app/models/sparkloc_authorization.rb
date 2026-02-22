# frozen_string_literal: true

class SparklocAuthorization < ActiveRecord::Base
  self.table_name = "sparkloc_authorizations"

  validates :discourse_id, presence: true
  validates :client_id, presence: true
end
