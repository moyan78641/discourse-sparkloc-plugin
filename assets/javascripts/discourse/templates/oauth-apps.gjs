import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

class OauthAppsPage extends Component {
  @tracked apps = [];
  @tracked authorizations = [];
  @tracked loadingApps = true;
  @tracked loadingAuths = true;
  @tracked showCreate = false;
  @tracked newName = "";
  @tracked newRedirectUris = "";
  @tracked createdApp = null;
  @tracked error = null;
  @tracked resetResult = null;
  @tracked editingAppId = null;
  @tracked editName = "";
  @tracked editRedirectUris = "";
  @tracked visibleSecretId = null;
  @tracked confirmAction = null;
  @tracked confirmMessage = "";
  @tracked copyFeedback = null;

  constructor() {
    super(...arguments);
    this.loadApps();
    this.loadAuthorizations();
  }

  async loadApps() {
    try {
      const data = await ajax("/sparkloc/apps.json");
      this.apps = data.apps || [];
    } catch (_) { /* ignore */ }
    finally { this.loadingApps = false; }
  }

  async loadAuthorizations() {
    try {
      const data = await ajax("/sparkloc/authorizations.json");
      this.authorizations = (data.authorizations || []).map((a) => ({
        ...a,
        statusText: a.status === "approved" ? "已授权" : "已撤销",
      }));
    } catch (_) { /* ignore */ }
    finally { this.loadingAuths = false; }
  }

  @action toggleCreate() {
    this.showCreate = !this.showCreate;
    this.editingAppId = null;
    this.error = null;
  }
  @action updateName(e) { this.newName = e.target.value; }
  @action updateRedirectUris(e) { this.newRedirectUris = e.target.value; }
  @action updateEditName(e) { this.editName = e.target.value; }
  @action updateEditRedirectUris(e) { this.editRedirectUris = e.target.value; }
  @action dismissCreated() { this.createdApp = null; }
  @action dismissReset() { this.resetResult = null; }

  @action startEdit(app) {
    this.editingAppId = app.id;
    this.editName = app.name;
    this.editRedirectUris = app.redirect_uris;
    this.showCreate = false;
    this.error = null;
  }

  @action cancelEdit() { this.editingAppId = null; }

  @action async saveEdit(appId) {
    this.error = null;
    if (!this.editName.trim() || !this.editRedirectUris.trim()) {
      this.error = "名称和回调地址不能为空";
      return;
    }
    try {
      await ajax(`/sparkloc/apps/${appId}.json`, {
        type: "PUT",
        data: { name: this.editName, redirect_uris: this.editRedirectUris },
      });
      this.editingAppId = null;
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "修改失败";
    }
  }

  @action async createApp() {
    this.error = null;
    this.createdApp = null;
    if (!this.newName.trim() || !this.newRedirectUris.trim()) {
      this.error = "名称和回调地址不能为空";
      return;
    }
    try {
      const result = await ajax("/sparkloc/apps.json", {
        type: "POST",
        data: { name: this.newName, redirect_uris: this.newRedirectUris },
      });
      this.createdApp = result;
      this.newName = "";
      this.newRedirectUris = "";
      this.showCreate = false;
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "创建失败";
    }
  }

  @action requestDelete(appId) {
    this.confirmMessage = "确定删除此应用？删除后不可恢复。";
    this.confirmAction = () => this.doDelete(appId);
  }

  @action requestReset(appId) {
    this.confirmMessage = "确定重置密钥？旧密钥将立即失效。";
    this.confirmAction = () => this.doReset(appId);
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

  async doDelete(appId) {
    try {
      await ajax(`/sparkloc/apps/${appId}.json`, { type: "DELETE" });
      this.createdApp = null;
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "删除失败";
    }
  }

  async doReset(appId) {
    try {
      const result = await ajax(`/sparkloc/apps/${appId}/reset-secret.json`, { type: "POST" });
      this.resetResult = result;
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "重置失败";
    }
  }

  @action toggleSecret(appId) {
    this.visibleSecretId = this.visibleSecretId === appId ? null : appId;
  }

  @action async copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      this.copyFeedback = text;
      setTimeout(() => { this.copyFeedback = null; }, 1500);
    } catch (_) { /* ignore */ }
  }

  get appsWithState() {
    return this.apps.map((app) => ({
      ...app,
      isEditing: app.id === this.editingAppId,
      isSecretVisible: app.id === this.visibleSecretId,
    }));
  }

  <template>
    <div class="sparkloc-oauth-apps-page">

      {{!-- 自定义确认弹窗 --}}
      {{#if this.confirmAction}}
        <div class="sparkloc-modal-overlay" {{on "click" this.cancelConfirm}} role="dialog">
          <div class="sparkloc-modal" {{on "click" this.stopProp}}>
            <p>{{this.confirmMessage}}</p>
            <div class="sparkloc-modal-actions">
              <button class="btn btn-danger" type="button" {{on "click" this.runConfirm}}>确定</button>
              <button class="btn btn-default" type="button" {{on "click" this.cancelConfirm}}>取消</button>
            </div>
          </div>
        </div>
      {{/if}}

      <h2>我的应用</h2>

      <div class="sparkloc-guide-box">
        <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#book"></use></svg>
        <div class="guide-content">
          <h3>{{i18n "sparkloc.oauth_apps.guide_title"}}</h3>
          <p>{{i18n "sparkloc.oauth_apps.guide_desc"}}</p>
          <a href="https://sparkloc.com/t/topic/39" target="_blank" rel="noopener noreferrer" class="btn btn-default">
            {{i18n "sparkloc.oauth_apps.guide_btn"}}
            <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#external-link-alt"></use></svg>
          </a>
        </div>
      </div>

      {{#if this.createdApp}}
        <div class="oauth-credential-notice">
          <h3>✅ 应用创建成功</h3>
          <div class="credential-row">
            <span class="credential-label">Client ID</span>
            <code class="credential-value">{{this.createdApp.client_id}}</code>
            <button class="btn btn-flat btn-small copy-btn" type="button" {{on "click" (fn this.copyText this.createdApp.client_id)}}>📋</button>
          </div>
          <div class="credential-row">
            <span class="credential-label">Client Secret</span>
            <code class="credential-value secret">{{this.createdApp.client_secret}}</code>
            <button class="btn btn-flat btn-small copy-btn" type="button" {{on "click" (fn this.copyText this.createdApp.client_secret)}}>📋</button>
          </div>
          <button class="btn btn-default" type="button" {{on "click" this.dismissCreated}}>知道了</button>
        </div>
      {{/if}}

      {{#if this.resetResult}}
        <div class="oauth-credential-notice">
          <h3>✅ 密钥已重置</h3>
          <div class="credential-row">
            <span class="credential-label">Client ID</span>
            <code class="credential-value">{{this.resetResult.client_id}}</code>
            <button class="btn btn-flat btn-small copy-btn" type="button" {{on "click" (fn this.copyText this.resetResult.client_id)}}>📋</button>
          </div>
          <div class="credential-row">
            <span class="credential-label">新 Secret</span>
            <code class="credential-value secret">{{this.resetResult.client_secret}}</code>
            <button class="btn btn-flat btn-small copy-btn" type="button" {{on "click" (fn this.copyText this.resetResult.client_secret)}}>📋</button>
          </div>
          <button class="btn btn-default" type="button" {{on "click" this.dismissReset}}>知道了</button>
        </div>
      {{/if}}

      {{#if this.error}}
        <div class="oauth-error-notice">{{this.error}}</div>
      {{/if}}

      <div class="oauth-actions-bar">
        <button class="btn btn-primary" type="button" {{on "click" this.toggleCreate}}>
          {{if this.showCreate "取消" "＋ 新建应用"}}
        </button>
      </div>

      {{#if this.showCreate}}
        <div class="oauth-create-form">
          <div class="form-row">
            <label for="app-name">应用名称</label>
            <input id="app-name" type="text" value={{this.newName}} {{on "input" this.updateName}} placeholder="我的应用" />
          </div>
          <div class="form-row">
            <label for="app-redirect">回调地址 (Redirect URI)</label>
            <input id="app-redirect" type="text" value={{this.newRedirectUris}} {{on "input" this.updateRedirectUris}} placeholder="https://example.com/callback" />
          </div>
          <button class="btn btn-primary" type="button" {{on "click" this.createApp}}>确认创建</button>
        </div>
      {{/if}}

      {{#if this.loadingApps}}
        <p class="loading-text">加载中...</p>
      {{else if this.apps.length}}
        <div class="oauth-apps-list">
          {{#each this.appsWithState as |app|}}
            {{#if app.isEditing}}
              <div class="oauth-app-card editing">
                <div class="form-row">
                  <label>名称</label>
                  <input type="text" value={{this.editName}} {{on "input" this.updateEditName}} />
                </div>
                <div class="form-row">
                  <label>回调地址</label>
                  <input type="text" value={{this.editRedirectUris}} {{on "input" this.updateEditRedirectUris}} />
                </div>
                <div class="card-actions">
                  <button class="btn btn-primary btn-small" type="button" {{on "click" (fn this.saveEdit app.id)}}>保存</button>
                  <button class="btn btn-default btn-small" type="button" {{on "click" this.cancelEdit}}>取消</button>
                </div>
              </div>
            {{else}}
              <div class="oauth-app-card">
                <div class="app-card-header">
                  <h3>{{app.name}}</h3>
                  <span class="app-created">{{app.created_at}}</span>
                </div>
                <div class="app-card-field">
                  <span class="field-label">Client ID</span>
                  <code>{{app.client_id}}</code>
                  <button class="btn btn-flat btn-small copy-btn" type="button" {{on "click" (fn this.copyText app.client_id)}} title="复制">📋</button>
                </div>
                <div class="app-card-field">
                  <span class="field-label">Client Secret</span>
                  {{#if app.isSecretVisible}}
                    <code>{{app.client_secret}}</code>
                  {{else}}
                    <code class="secret-masked">••••••••••••••••</code>
                  {{/if}}
                  <button class="btn btn-flat btn-small secret-toggle" type="button" {{on "click" (fn this.toggleSecret app.id)}} title="显示/隐藏">
                    {{#if app.isSecretVisible}}🙈{{else}}👁{{/if}}
                  </button>
                  {{#if app.isSecretVisible}}
                    <button class="btn btn-flat btn-small copy-btn" type="button" {{on "click" (fn this.copyText app.client_secret)}} title="复制">📋</button>
                  {{/if}}
                </div>
                <div class="app-card-field">
                  <span class="field-label">回调地址</span>
                  <span class="field-value">{{app.redirect_uris}}</span>
                </div>
                <div class="card-actions">
                  <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.startEdit app)}}>编辑</button>
                  <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.requestReset app.id)}}>重置密钥</button>
                  <button class="btn btn-danger btn-small" type="button" {{on "click" (fn this.requestDelete app.id)}}>删除</button>
                </div>
              </div>
            {{/if}}
          {{/each}}
        </div>
      {{else}}
        <p class="no-apps-text">您还没有创建应用。</p>
      {{/if}}

      <h2 class="section-title">已授权的应用</h2>

      {{#if this.loadingAuths}}
        <p class="loading-text">加载中...</p>
      {{else if this.authorizations.length}}
        <div class="oauth-apps-list">
          {{#each this.authorizations as |auth|}}
            <div class="oauth-app-card auth-card">
              <div class="app-card-header">
                <h3>{{auth.app_name}}</h3>
                <span class="app-created">{{auth.created_at}}</span>
              </div>
              <div class="app-card-field">
                <span class="field-label">状态</span>
                <span class="field-value">{{auth.statusText}}</span>
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <p class="no-apps-text">暂无已授权的应用。</p>
      {{/if}}

    </div>
  </template>
}

export default RouteTemplate(<template><OauthAppsPage /></template>);
