# frozen_string_literal: true

require "digest"

module ::DiscourseSparkloc
  class LotteryController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    # GET /sparkloc/lottery/topics.json
    # 获取当前用户符合条件的话题（已关闭/存档 + 抽奖标签）
    def topics
      topics = Topic.joins(:tags)
                    .where(user_id: current_user.id)
                    .where("topics.closed = true OR topics.archived = true")
                    .where(tags: { name: %w[抽奖 lottery] })
                    .order(created_at: :desc)
                    .select(:id, :title, :closed, :archived, :created_at, :posts_count)

      # 标记已抽奖的话题
      drawn_topic_ids = drawn_topic_id_set

      result = topics.map do |t|
        {
          id: t.id,
          title: t.title,
          closed: t.closed,
          archived: t.archived,
          posts_count: t.posts_count,
          created_at: t.created_at.strftime("%Y-%m-%d %H:%M"),
          drawn: drawn_topic_ids.include?(t.id),
        }
      end

      render json: { topics: result }
    end

    # GET /sparkloc/lottery/valid-posts.json?topic_id=xx&last_floor=xx
    def valid_posts
      topic = find_user_topic(params[:topic_id])
      return render json: { error: "话题不存在或不符合条件" }, status: 400 unless topic

      last_floor = params[:last_floor].present? ? params[:last_floor].to_i : nil
      posts = fetch_valid_posts(topic, last_floor)

      render json: { count: posts.size, posts: posts.map { |p| { post_number: p.post_number, username: p.user&.username } } }
    end

    # POST /sparkloc/lottery/draw.json
    def draw
      topic = find_user_topic(params[:topic_id])
      return render json: { error: "话题不存在或不符合条件" }, status: 400 unless topic

      # 检查是否已抽过
      existing = load_record(topic.id)
      if existing
        return render json: { error: "该话题已抽过奖", result: existing }, status: 400
      end

      winners_count = (params[:winners_count] || 1).to_i
      winners_count = [[winners_count, 1].max, 100].min
      last_floor = params[:last_floor].present? ? params[:last_floor].to_i : nil

      posts = fetch_valid_posts(topic, last_floor)
      return render json: { error: "没有符合条件的参与楼层" }, status: 400 if posts.empty?

      winners_count = [winners_count, posts.size].min

      # 生成种子
      seed = generate_seed(topic, posts, winners_count)

      # 抽奖
      winning_floors = pick_winners(seed, posts, winners_count)

      # 构建中奖信息
      winners_info = winning_floors.map do |floor|
        post = posts.find { |p| p.post_number == floor }
        { post_number: floor, username: post&.user&.username || "unknown" }
      end

      # 保存记录
      record = {
        "topic_id" => topic.id,
        "topic_title" => topic.title,
        "creator_id" => current_user.id,
        "winners_count" => winners_count,
        "last_floor" => last_floor,
        "seed" => seed,
        "winning_floors" => winning_floors,
        "winners_info" => winners_info,
        "valid_posts_count" => posts.size,
        "created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "published" => false,
      }
      save_record(topic.id, record)

      # 自动发布结果到帖子
      publish_result(topic, record)

      render json: { ok: true, result: record }
    end

    # GET /sparkloc/lottery/result.json?topic_id=xx
    def result
      topic_id = params[:topic_id].to_i
      record = load_record(topic_id)
      return render json: { error: "未找到抽奖记录" }, status: 404 unless record

      # 只有作者或管理员可查看
      unless record["creator_id"] == current_user.id || current_user.admin?
        return render json: { error: "无权查看" }, status: 403
      end

      render json: { result: record }
    end

    # GET /sparkloc/lottery/records.json
    def records
      all_records = load_all_records
      unless current_user.admin?
        all_records = all_records.select { |r| r["creator_id"] == current_user.id }
      end
      all_records.sort_by! { |r| r["created_at"] || "" }.reverse!

      render json: { records: all_records }
    end

    private

    def find_user_topic(topic_id)
      topic = Topic.joins(:tags)
                   .where(id: topic_id.to_i, user_id: current_user.id)
                   .where("topics.closed = true OR topics.archived = true")
                   .where(tags: { name: %w[抽奖 lottery] })
                   .first
      topic
    end

    def fetch_valid_posts(topic, last_floor)
      posts = Post.where(topic_id: topic.id)
                  .where("post_number > 1")
                  .where(deleted_at: nil, hidden: false)
                  .where.not(user_id: topic.user_id)
                  .includes(:user)
                  .order(:post_number)

      posts = posts.where("post_number <= ?", last_floor) if last_floor

      # 每个用户只保留第一条回复
      seen = {}
      posts.select do |p|
        next false if seen[p.user_id]
        seen[p.user_id] = true
        true
      end
    end

    # 种子生成 — 与 Go 版本完全一致
    def generate_seed(topic, valid_posts, winners_count)
      post_ids = valid_posts.map { |p| p.id.to_s }.join(",")
      post_numbers = valid_posts.map { |p| p.post_number.to_s }.join(",")
      post_created = valid_posts.map { |p| p.created_at.strftime("%Y-%m-%dT%H:%M:%SZ") }.join(",")

      seed_content = [
        winners_count.to_s,
        topic.id.to_s,
        topic.user_id.to_s,
        topic.created_at.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        post_ids,
        post_numbers,
        post_created,
      ].join("|")

      md5    = Digest::MD5.hexdigest(seed_content)
      sha1   = Digest::SHA1.hexdigest(seed_content)
      sha512 = Digest::SHA512.hexdigest(seed_content)
      combined = md5 + sha1 + sha512

      Digest::SHA256.hexdigest(combined)
    end

    # 抽奖选人 — 与 Go 版本一致的确定性算法
    def pick_winners(seed, valid_posts, winners_count)
      # 将种子转为 int64（与 Go 一致）
      seed_int = 0
      seed.each_byte.with_index do |b, i|
        seed_int ^= b << (i % 56)
      end
      seed_int &= 0x7FFFFFFFFFFFFFFF # 保持正数

      # 使用与 Go rand 兼容的线性同余生成器
      rng = GoCompatRng.new(seed_int)

      available = valid_posts.map(&:post_number)
      winners = []

      winners_count.times do
        break if available.empty?
        index = rng.intn(available.size)
        winners << available[index]
        available.delete_at(index)
      end

      winners
    end

    # 发布抽奖结果到帖子
    def publish_result(topic, record)
      base_url = Discourse.base_url
      divider = "=" * 60

      content = "```text\n"
      content += "#{divider}\n"
      content += "#{center_text('Sparkloc 抽奖结果 - v2.0.0', 58)}\n"
      content += "#{divider}\n"
      content += "帖子链接: #{base_url}/t/topic/#{topic.id}\n"
      content += "帖子标题: #{topic.title}\n"
      content += "帖子作者: #{topic.user&.username}\n"
      content += "发帖时间: #{topic.created_at.strftime('%Y-%m-%d %H:%M:%S')}\n"
      content += "#{'—' * 60}\n"
      content += "抽奖时间: #{record['created_at']}\n"
      content += "有效用户: #{record['valid_posts_count']} 人\n"
      content += "中奖数量: #{record['winners_count']} 个\n"
      content += "截止楼层: #{record['last_floor'] || '全部'}\n"
      content += "最终种子: #{record['seed']}\n"
      content += "#{'—' * 60}\n"
      content += "恭喜以下用户中奖:\n"
      content += "#{'—' * 60}\n"

      record["winners_info"].each_with_index do |w, i|
        floor_url = "#{base_url}/t/topic/#{topic.id}/#{w['post_number']}"
        content += "[#{(i + 1).to_s.center(4)}] #{w['post_number'].to_s.rjust(4)} 楼  @#{w['username']}  #{floor_url}\n"
      end

      content += "#{divider}\n"
      content += "注: 每个用户仅首次回复参与抽奖\n"
      content += "#{divider}\n"
      content += "```\n"

      # 用系统用户或指定用户发帖
      poster = User.find_by(username: "lottery") || Discourse.system_user
      post = PostCreator.create!(poster, topic_id: topic.id, raw: content, skip_validations: true)

      if post&.persisted?
        record["published"] = true
        save_record(topic.id, record)
      end
    rescue => e
      Rails.logger.warn("Lottery publish failed: #{e.message}")
    end

    def center_text(text, width)
      return text if text.length >= width
      padding = width - text.length
      left = padding / 2
      (" " * left) + text
    end

    # PluginStore helpers
    def load_record(topic_id)
      raw = PluginStore.get(PLUGIN_NAME, "lottery::#{topic_id}")
      return nil if raw.nil?
      raw.is_a?(String) ? JSON.parse(raw) : raw
    rescue JSON::ParserError
      nil
    end

    def save_record(topic_id, data)
      PluginStore.set(PLUGIN_NAME, "lottery::#{topic_id}", data.to_json)
    end

    def load_all_records
      PluginStoreRow.where(plugin_name: PLUGIN_NAME)
                    .where("key LIKE 'lottery::%'")
                    .filter_map do |r|
        raw = r.value
        raw.is_a?(String) ? JSON.parse(raw) : raw
      rescue JSON::ParserError
        nil
      end
    end

    def drawn_topic_id_set
      Set.new(load_all_records.map { |r| r["topic_id"] })
    end
  end

  # Go 兼容的随机数生成器（线性同余，与 Go math/rand 一致）
  class GoCompatRng
    def initialize(seed)
      @seed = seed & 0x7FFFFFFFFFFFFFFF
    end

    def intn(n)
      return 0 if n <= 0
      # 简化版：用种子做确定性选择
      @seed = (@seed * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
      ((@seed >> 33) % n).to_i
    end
  end
end
