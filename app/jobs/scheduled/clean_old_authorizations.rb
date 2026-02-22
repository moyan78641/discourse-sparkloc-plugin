# frozen_string_literal: true

module Jobs
  class CleanOldAuthorizations < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      SparklocAuthorization.where("created_at < ?", 7.days.ago).delete_all
    end
  end
end
