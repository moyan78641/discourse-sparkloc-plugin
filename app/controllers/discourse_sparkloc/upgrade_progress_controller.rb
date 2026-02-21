# frozen_string_literal: true

module ::DiscourseSparkloc
  class UpgradeProgressController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    def index
      user = current_user
      trust_level = user.trust_level

      # TL4 is manual promotion, no auto-upgrade
      if trust_level >= 4
        return render json: {
          current_level: trust_level,
          next_level: 4,
          next_level_name: tl_name(4),
          progress: 100,
          requirements: []
        }
      end

      if trust_level >= 2
        render json: build_tl3_progress(user)
      elsif trust_level == 1
        render json: build_tl2_progress(user)
      else
        render json: build_tl1_progress(user)
      end
    end

    private

    def build_tl1_progress(user)
      reqs = [
        req("进入话题数", user.user_stat.topics_entered, SiteSetting.tl1_requires_topics_entered),
        req("阅读帖子数", user.user_stat.posts_read_count, SiteSetting.tl1_requires_read_posts),
        req("阅读时长(分钟)", (user.user_stat.time_read / 60.0).floor, SiteSetting.tl1_requires_time_spent_mins),
      ]
      build_result(0, 1, tl_name(1), reqs)
    end

    def build_tl2_progress(user)
      stat = user.user_stat
      reqs = [
        req("进入话题数", stat.topics_entered, SiteSetting.tl2_requires_topics_entered),
        req("阅读帖子数", stat.posts_read_count, SiteSetting.tl2_requires_read_posts),
        req("阅读时长(分钟)", (stat.time_read / 60.0).floor, SiteSetting.tl2_requires_time_spent_mins),
        req("访问天数", stat.days_visited, SiteSetting.tl2_requires_days_visited),
        req("收到的赞", stat.likes_received, SiteSetting.tl2_requires_likes_received),
        req("送出的赞", stat.likes_given, SiteSetting.tl2_requires_likes_given),
        req("回复话题数", stat.post_count, SiteSetting.tl2_requires_topic_reply_count),
        req_bool("未被禁言", !user.silenced?),
        req_bool("未被封禁", !user.suspended?),
      ]
      build_result(1, 2, tl_name(2), reqs)
    end

    def build_tl3_progress(user)
      tl3 = user.tl3_requirements
      unless tl3
        return {
          current_level: user.trust_level,
          next_level: 3,
          next_level_name: tl_name(3),
          progress: 0,
          requirements: []
        }
      end

      reqs = [
        req("访问天数", tl3.days_visited, tl3.min_days_visited),
        req("回复话题数", tl3.num_topics_replied_to, tl3.min_topics_replied_to),
        req("浏览话题数", tl3.topics_viewed, tl3.min_topics_viewed),
        req("阅读帖子数", tl3.posts_read, tl3.min_posts_read),
        req("浏览话题数(总计)", tl3.topics_viewed_all_time, tl3.min_topics_viewed_all_time),
        req("阅读帖子数(总计)", tl3.posts_read_all_time, tl3.min_posts_read_all_time),
        req("送出的赞", tl3.num_likes_given, tl3.min_likes_given),
        req("收到的赞", tl3.num_likes_received, tl3.min_likes_received),
        req_max("被举报帖子数(不超过)", tl3.num_flagged_posts, tl3.max_flagged_posts),
        req_bool("未被禁言", !user.silenced?),
        req_bool("未被封禁", !user.suspended?),
      ]
      build_result(user.trust_level, 3, tl_name(3), reqs)
    end

    def req(name, current, required)
      current = current.to_i
      required = required.to_i
      { name: name, current: current, required: required, met: current >= required }
    end

    def req_bool(name, met)
      { name: name, current: nil, required: nil, met: met, bool: true }
    end

    def req_max(name, current, max_allowed)
      current = current.to_i
      max_allowed = max_allowed.to_i
      { name: name, current: current, required: max_allowed, met: current <= max_allowed }
    end

    # Get trust level display name from automatic group full_name
    TL_FALLBACK = { 0 => "新用户", 1 => "基础用户", 2 => "活跃用户", 3 => "资深用户", 4 => "最高等级" }.freeze

    def tl_name(level)
      group = Group.find_by(name: "trust_level_#{level}")
      name = group&.full_name.presence
      name || TL_FALLBACK[level] || "等级#{level}"
    end

    def build_result(current_level, next_level, next_level_name, reqs)
      met_count = reqs.count { |r| r[:met] }
      progress = reqs.empty? ? 100 : (met_count * 100 / reqs.size)
      {
        current_level: current_level,
        next_level: next_level,
        next_level_name: next_level_name,
        progress: progress,
        requirements: reqs
      }
    end
  end
end
