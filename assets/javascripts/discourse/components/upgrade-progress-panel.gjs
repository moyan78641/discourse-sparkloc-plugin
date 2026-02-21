import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class UpgradeProgressPanel extends Component {
  @tracked loading = true;
  @tracked progress = null;
  @tracked error = false;

  constructor() {
    super(...arguments);
    this.loadProgress();
  }

  async loadProgress() {
    try {
      this.progress = await ajax("/sparkloc/upgrade-progress.json");
    } catch (e) {
      this.error = true;
    } finally {
      this.loading = false;
    }
  }

  get isMaxLevel() {
    return this.progress && this.progress.progress === 100 && this.progress.next_level === 4;
  }

  get isAllMet() {
    return this.progress && this.progress.progress === 100 && this.progress.next_level !== 4;
  }

  get unmetRequirements() {
    if (!this.progress || !this.progress.requirements) return [];
    return this.progress.requirements.filter((r) => !r.met);
  }

  get metRequirements() {
    if (!this.progress || !this.progress.requirements) return [];
    return this.progress.requirements.filter((r) => r.met);
  }

  <template>
    <div class="upgrade-progress-panel">
      {{#if this.loading}}
        <p class="loading-text">加载中...</p>
      {{else if this.error}}
        <p class="error-text">无法加载升级进度</p>
      {{else if this.progress}}
        {{#if this.isMaxLevel}}
          <h3>🎉 已达最高等级</h3>
        {{else if this.isAllMet}}
          <h3>✅ 已满足所有条件</h3>
        {{else}}
          <h3>下一等级：{{this.progress.next_level_name}}</h3>
          <div class="upgrade-progress-bar">
            <div
              class="progress"
              style="width: {{this.progress.progress}}%;"
            ></div>
          </div>
        {{/if}}

        {{#if this.unmetRequirements.length}}
          <h4>未满足条件</h4>
          <ul class="req-list">
            {{#each this.unmetRequirements as |req|}}
              {{#if req.bool}}
                <li>{{req.name}}</li>
              {{else}}
                <li>{{req.name}}：{{req.current}}/{{req.required}}</li>
              {{/if}}
            {{/each}}
          </ul>
        {{/if}}

        {{#if this.metRequirements.length}}
          <h4>已满足条件</h4>
          <ul class="req-list met">
            {{#each this.metRequirements as |req|}}
              <li>{{req.name}}</li>
            {{/each}}
          </ul>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
