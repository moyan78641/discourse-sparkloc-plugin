import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";

class MerchantsPage extends Component {
  @tracked merchants = [];
  @tracked loading = true;
  @tracked error = false;

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    try {
      const data = await ajax("/sparkloc/merchants.json");
      this.merchants = data.merchants || [];
    } catch (_) {
      this.error = true;
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="sparkloc-merchants-page">
      <h2>认证商家</h2>
      {{#if this.loading}}
        <p class="loading-text">加载中...</p>
      {{else if this.error}}
        <p class="error-text">加载失败</p>
      {{else if this.merchants.length}}
        <div class="merchants-grid">
          {{#each this.merchants as |merchant|}}
            <div class="merchant-card">
              <div class="merchant-card-inner">
                <div class="merchant-card-front">
                  {{#if merchant.logo_url}}
                    <img class="merchant-logo" src={{merchant.logo_url}} alt={{merchant.name}} loading="lazy" />
                  {{else}}
                    <div class="merchant-logo-placeholder">{{merchant.name}}</div>
                  {{/if}}
                </div>
                <div class="merchant-card-back">
                  <h3 class="merchant-name">{{merchant.name}}</h3>
                  {{#if merchant.description}}
                    <p class="merchant-desc">{{merchant.description}}</p>
                  {{/if}}
                  {{#if merchant.website}}
                    <a class="merchant-link" href={{merchant.website}} target="_blank" rel="noopener noreferrer">官网</a>
                  {{/if}}
                  {{#if merchant.discourse_username}}
                    <a class="merchant-link" href="/u/{{merchant.discourse_username}}">论坛主页</a>
                  {{/if}}
                </div>
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <p class="no-data-text">暂无认证商家</p>
      {{/if}}
    </div>
  </template>
}

export default RouteTemplate(<template><MerchantsPage /></template>);
