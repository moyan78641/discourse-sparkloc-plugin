# frozen_string_literal: true

class SparklocLotteryRecord < ActiveRecord::Base
  self.table_name = "sparkloc_lottery_records"

  validates :topic_id, presence: true, uniqueness: true
  validates :creator_id, presence: true
  validates :winners_count, presence: true
end
