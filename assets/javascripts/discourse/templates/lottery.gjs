import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

class LotteryPage extends Component {
  @tracked topics = [];
  @tracked loadingTopics = true;
  @tracked selectedTopicId = null;
  @tracked winnersCount = 1;
  @tracked lastFloor = "";
  @tracked validPostsCount = null;
  @tracked drawing = false;
  @tracked result = null;
  @tracked error = null;
  @tracked copyFeedback = null;

  constructor() {
    super(...arguments);
    this.loadTopics();
  }

  async loadTopics() {
    try {
      const data = await ajax("/sparkloc/lottery/topics.json");
      this.topics = data.topics || [];
    } catch (_) { /* ignore */ }
    finally { this.loadingTopics = false; }
  }

  get selectedTopic() {
    if (!this.selectedTopicId) return null;
    return this.topics.find((t) => t.id === this.selectedTopicId);
  }

  get isDrawn() {
    return this.selectedTopic?.drawn;
  }

  @action selectTopic(e) {
    const id = parseInt(e.target.value, 10);
    this.selectedTopicId = id || null;
    this.result = null;
    this.error = null;
    this.validPostsCount = null;

    if (this.selectedTopicId) {
      const topic = this.selectedTopic;
      if (topic?.drawn) {
        this.loadResult(this.selectedTopicId);
      } else {
        this.loadValidPosts();
      }
    }
  }

  @action updateWinnersCount(e) {
    this.winnersCount = parseInt(e.target.value, 10) || 1;
  }

  @action updateLastFloor(e) {
    this.lastFloor = e.target.value;
  }

  async loadValidPosts() {
    try {
      let url = `/sparkloc/lottery/valid-posts.json?topic_id=${this.selectedTopicId}`;
      if (this.lastFloor) url += `&last_floor=${this.lastFloor}`;
      const data = await ajax(url);
      this.validPostsCount = data.count;
    } catch (_) { this.validPostsCount = null; }
  }

  async loadResult(topicId) {
    try {
      const data = await ajax(`/sparkloc/lottery/result.json?topic_id=${topicId}`);
      this.result = data.result;
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "加载结果失败";
    }
  }

  @action async refreshValidPosts() {
    if (this.selectedTopicId && !this.isDrawn) {
      await this.loadValidPosts();
    }
  }

  @action async doDraw() {
    this.error = null;
    this.drawing = true;
    try {
      const data = await ajax("/sparkloc/lottery/draw.json", {
        type: "POST",
        data: {
          topic_id: this.selectedTopicId,
          winners_count: this.winnersCount,
          last_floor: this.lastFloor || undefined,
        },
      });
      this.result = data.result;
      // 刷新话题列表标记已抽奖
      await this.loadTopics();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "抽奖失败";
    } finally {
      this.drawing = false;
    }
  }

  @action async copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      this.copyFeedback = true;
      setTimeout(() => { this.copyFeedback = null; }, 1500);
    } catch (_) { /* ignore */ }
  }

  <template>
    <div class="sparkloc-lottery-page">

      {{#if this.copyFeedback}}
        <div class="copy-toast">已复制到剪贴板</div>
      {{/if}}

      <h2>🎯 抽奖</h2>

      <div class="sparkloc-guide-box">
        <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#book"></use></svg>
        <div class="guide-content">
          <h3>抽奖规则</h3>
          <p>话题需带有「抽奖」标签并已关闭/存档。每个话题只能抽奖一次，每个用户仅首次回复参与，楼主不参与。结果自动发布到原帖。</p>
          <a href="https://sparkloc.com/t/topic/46" target="_blank" rel="noopener noreferrer" class="btn btn-default">
            抽奖指南
            <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#external-link-alt"></use></svg>
          </a>
        </div>
      </div>

      {{#if this.error}}
        <div class="oauth-error-notice">{{this.error}}</div>
      {{/if}}

      <div class="lottery-select-section">
        <label for="lottery-topic-select">选择话题</label>
        {{#if this.loadingTopics}}
          <p class="loading-text">加载中...</p>
        {{else if this.topics.length}}
          <select id="lottery-topic-select" class="lottery-topic-dropdown" {{on "change" this.selectTopic}}>
            <option value="">— 请选择话题 —</option>
            {{#each this.topics as |topic|}}
              <option value={{topic.id}}>
                {{topic.title}}{{if topic.drawn " 🎯 已抽奖" ""}}
              </option>
            {{/each}}
          </select>
        {{else}}
          <p class="no-apps-text">暂无符合条件的话题（需已关闭/存档 + 抽奖标签）</p>
        {{/if}}
      </div>

      {{#if this.selectedTopic}}
        <div class="lottery-topic-info">
          <span class="lottery-topic-title">{{this.selectedTopic.title}}</span>
          <span class="lottery-topic-meta">
            {{this.selectedTopic.posts_count}} 楼 · {{this.selectedTopic.created_at}}
          </span>
        </div>

        {{#if this.isDrawn}}
          {{!-- 已抽奖：显示结果 --}}
          {{#if this.result}}
            <div class="lottery-result-card">
              <h3>🎉 抽奖结果</h3>
              <div class="lottery-result-meta">
                <span>有效用户: {{this.result.valid_posts_count}} 人</span>
                <span>中奖数量: {{this.result.winners_count}} 个</span>
                <span>抽奖时间: {{this.result.created_at}}</span>
              </div>
              <div class="lottery-seed">
                <span class="seed-label">种子值</span>
                <code>{{this.result.seed}}</code>
                <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.result.seed)}} title="复制">
                  <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
                </button>
              </div>
              <div class="lottery-winners-list">
                <div class="lottery-winners-header">
                  <span class="lw-col-num">#</span>
                  <span class="lw-col-floor">楼层</span>
                  <span class="lw-col-user">用户</span>
                </div>
                {{#each this.result.winners_info as |winner|}}
                  <div class="lottery-winners-row">
                    <span class="lw-col-num">{{winner.post_number}}</span>
                    <span class="lw-col-floor">
                      <a href="/t/topic/{{this.result.topic_id}}/{{winner.post_number}}" target="_blank" rel="noopener noreferrer">{{winner.post_number}} 楼</a>
                    </span>
                    <span class="lw-col-user">
                      <a href="/u/{{winner.username}}">@{{winner.username}}</a>
                    </span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{else}}
            <p class="loading-text">加载结果中...</p>
          {{/if}}

        {{else}}
          {{!-- 未抽奖：显示操作区 --}}
          <div class="lottery-draw-card">
            {{#if this.validPostsCount}}
              <p class="lottery-valid-count">有效参与用户: <strong>{{this.validPostsCount}}</strong> 人</p>
            {{/if}}
            <div class="lottery-form">
              <div class="form-row">
                <label for="winners-count">中奖人数</label>
                <input id="winners-count" type="number" min="1" max="100" value={{this.winnersCount}} {{on "input" this.updateWinnersCount}} />
              </div>
              <div class="form-row">
                <label for="last-floor">截止楼层（选填）</label>
                <input id="last-floor" type="number" min="2" value={{this.lastFloor}} {{on "input" this.updateLastFloor}} {{on "blur" this.refreshValidPosts}} placeholder="不填则全部楼层参与" />
              </div>
              <button class="btn btn-primary" type="button" disabled={{this.drawing}} {{on "click" this.doDraw}}>
                {{if this.drawing "抽奖中..." "🎯 开始抽奖"}}
              </button>
            </div>
          </div>

          {{!-- 刚抽完也显示结果 --}}
          {{#if this.result}}
            <div class="lottery-result-card">
              <h3>🎉 抽奖结果</h3>
              <div class="lottery-result-meta">
                <span>有效用户: {{this.result.valid_posts_count}} 人</span>
                <span>中奖数量: {{this.result.winners_count}} 个</span>
              </div>
              <div class="lottery-seed">
                <span class="seed-label">种子值</span>
                <code>{{this.result.seed}}</code>
                <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.result.seed)}} title="复制">
                  <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
                </button>
              </div>
              <div class="lottery-winners-list">
                <div class="lottery-winners-header">
                  <span class="lw-col-num">#</span>
                  <span class="lw-col-floor">楼层</span>
                  <span class="lw-col-user">用户</span>
                </div>
                {{#each this.result.winners_info as |winner|}}
                  <div class="lottery-winners-row">
                    <span class="lw-col-num">{{winner.post_number}}</span>
                    <span class="lw-col-floor">
                      <a href="/t/topic/{{this.result.topic_id}}/{{winner.post_number}}" target="_blank" rel="noopener noreferrer">{{winner.post_number}} 楼</a>
                    </span>
                    <span class="lw-col-user">
                      <a href="/u/{{winner.username}}">@{{winner.username}}</a>
                    </span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
        {{/if}}
      {{/if}}

    </div>
  </template>
}

export default RouteTemplate(<template><LotteryPage /></template>);
