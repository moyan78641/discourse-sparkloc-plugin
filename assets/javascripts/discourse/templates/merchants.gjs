import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import { i18n } from "discourse-i18n";

class MerchantsPage extends Component {
  @service currentUser;

  @tracked merchants = [];
  @tracked loading = true;
  @tracked error = false;
  @tracked showForm = false;
  @tracked editingId = null;
  @tracked formName = "";
  @tracked formLogoUrl = "";
  @tracked formWebsite = "";
  @tracked formUsername = "";
  @tracked formDescription = "";
  @tracked formSortOrder = "0";
  @tracked formError = null;
  @tracked saving = false;

  @tracked confirmAction = null;
  @tracked confirmMessage = "";

  constructor() {
    super(...arguments);
    this.loadData();
  }

  get isAdmin() {
    return this.currentUser && this.currentUser.admin;
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

  @action showAddForm() {
    this.editingId = null;
    this.formName = "";
    this.formLogoUrl = "";
    this.formWebsite = "";
    this.formUsername = "";
    this.formDescription = "";
    this.formSortOrder = "0";
    this.formError = null;
    this.showForm = true;
  }

  @action showEditForm(m) {
    this.editingId = m.id;
    this.formName = m.name;
    this.formLogoUrl = m.logo_url || "";
    this.formWebsite = m.website || "";
    this.formUsername = m.discourse_username || "";
    this.formDescription = m.description || "";
    this.formSortOrder = String(m.sort_order || 0);
    this.formError = null;
    this.showForm = true;
  }

  @action cancelForm() {
    this.showForm = false;
    this.editingId = null;
  }

  @action onName(e) { this.formName = e.target.value; }
  @action onLogoUrl(e) { this.formLogoUrl = e.target.value; }
  @action onWebsite(e) { this.formWebsite = e.target.value; }
  @action onUsername(e) { this.formUsername = e.target.value; }
  @action onDescription(e) { this.formDescription = e.target.value; }
  @action onSortOrder(e) { this.formSortOrder = e.target.value; }

  @action async saveForm() {
    if (!this.formName.trim()) {
      this.formError = "商家名称不能为空";
      return;
    }
    this.saving = true;
    this.formError = null;
    const payload = {
      name: this.formName,
      logo_url: this.formLogoUrl,
      website: this.formWebsite,
      discourse_username: this.formUsername,
      description: this.formDescription,
      sort_order: this.formSortOrder,
    };
    try {
      if (this.editingId) {
        await ajax(`/sparkloc/admin/merchants/${this.editingId}.json`, {
          type: "PUT", data: payload,
        });
      } else {
        await ajax("/sparkloc/admin/merchants.json", {
          type: "POST", data: payload,
        });
      }
      this.showForm = false;
      this.editingId = null;
      this.loading = true;
      await this.loadData();
    } catch (e) {
      this.formError = e.jqXHR?.responseJSON?.error || "保存失败";
    } finally {
      this.saving = false;
    }
  }

  @action requestDelete(id) {
    this.confirmMessage = "确定删除此商家？";
    this.confirmAction = () => this.doDelete(id);
  }

  @action cancelConfirm() { this.confirmAction = null; this.confirmMessage = ""; }

  @action async runConfirm() {
    if (this.confirmAction) {
      const fn = this.confirmAction;
      this.confirmAction = null;
      this.confirmMessage = "";
      await fn();
    }
  }

  async doDelete(id) {
    try {
      await ajax(`/sparkloc/admin/merchants/${id}.json`, { type: "DELETE" });
      this.loading = true;
      await this.loadData();
    } catch (e) {
      this.formError = e.jqXHR?.responseJSON?.error || "删除失败";
    }
  }

  <template>
    <div class="sparkloc-merchants-page">

      {{#if this.confirmAction}}
        <div class="sparkloc-modal-overlay" {{on "click" this.cancelConfirm}} role="dialog">
          <div class="sparkloc-modal">
            <p>{{this.confirmMessage}}</p>
            <div class="sparkloc-modal-actions">
              <button class="btn btn-danger" type="button" {{on "click" this.runConfirm}}>确定</button>
              <button class="btn btn-default" type="button" {{on "click" this.cancelConfirm}}>取消</button>
            </div>
          </div>
        </div>
      {{/if}}

      <h2>认证商家</h2>

      <div class="sparkloc-guide-box compact">
        <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#certificate"></use></svg>
        <div class="guide-content">
          <p>{{i18n "sparkloc.merchants.guide_desc"}}</p>
          <a href="https://sparkloc.com/t/topic/32" target="_blank" rel="noopener noreferrer" class="btn btn-small btn-default">
            {{i18n "sparkloc.merchants.guide_btn"}}
            <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#external-link-alt"></use></svg>
          </a>
        </div>
      </div>

      {{#if this.isAdmin}}
        <div class="merchant-admin-bar">
          <button class="btn btn-primary" type="button" {{on "click" this.showAddForm}}>＋ 添加商家</button>
        </div>
      {{/if}}

      {{#if this.formError}}
        <div class="oauth-error-notice">{{this.formError}}</div>
      {{/if}}

      {{#if this.showForm}}
        <div class="merchant-form">
          <h3>{{if this.editingId "编辑商家" "添加商家"}}</h3>
          <div class="form-row">
            <label>商家名称 *</label>
            <input type="text" value={{this.formName}} {{on "input" this.onName}} placeholder="商家名称" />
          </div>
          <div class="form-row">
            <label>Logo URL</label>
            <input type="text" value={{this.formLogoUrl}} {{on "input" this.onLogoUrl}} placeholder="https://example.com/logo.png" />
          </div>
          <div class="form-row">
            <label>官网</label>
            <input type="text" value={{this.formWebsite}} {{on "input" this.onWebsite}} placeholder="https://example.com" />
          </div>
          <div class="form-row">
            <label>论坛用户名</label>
            <input type="text" value={{this.formUsername}} {{on "input" this.onUsername}} placeholder="discourse_username" />
          </div>
          <div class="form-row">
            <label>描述</label>
            <textarea value={{this.formDescription}} {{on "input" this.onDescription}} placeholder="商家简介" rows="3"></textarea>
          </div>
          <div class="form-row">
            <label>排序 (数字越小越靠前)</label>
            <input type="number" value={{this.formSortOrder}} {{on "input" this.onSortOrder}} />
          </div>
          <div class="form-actions">
            <button class="btn btn-primary" type="button" {{on "click" this.saveForm}} disabled={{this.saving}}>
              {{if this.saving "保存中..." "保存"}}
            </button>
            <button class="btn btn-default" type="button" {{on "click" this.cancelForm}}>取消</button>
          </div>
        </div>
      {{/if}}

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
                  {{#if merchant.website}}
                    <a class="merchant-name-link" href={{merchant.website}} target="_blank" rel="noopener noreferrer">
                      <h3 class="merchant-name">{{merchant.name}}</h3>
                    </a>
                  {{else}}
                    <h3 class="merchant-name">{{merchant.name}}</h3>
                  {{/if}}
                  {{#if merchant.description}}
                    <p class="merchant-desc">{{merchant.description}}</p>
                  {{/if}}
                  {{#if merchant.discourse_username}}
                    <a class="merchant-username-btn" href="/u/{{merchant.discourse_username}}">@{{merchant.discourse_username}}</a>
                  {{/if}}
                  {{#if this.isAdmin}}
                    <div class="merchant-admin-actions">
                      <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.showEditForm merchant)}}>编辑</button>
                      <button class="btn btn-danger btn-small" type="button" {{on "click" (fn this.requestDelete merchant.id)}}>删除</button>
                    </div>
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
