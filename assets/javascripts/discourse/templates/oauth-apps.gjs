import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { service } from "@ember/service";

class OauthAppsPage extends Component {
  @service currentUser;
  @service siteSettings;
  @tracked apps = [];
  @tracked authorizations = [];
  @tracked loadingApps = true;
  @tracked loadingAuths = true;
  @tracked showCreate = false;
  @tracked newName = "";
  @tracked newDescription = "";
  @tracked newRedirectUris = "";
  @tracked createdApp = null;
  @tracked error = null;
  @tracked resetResult = null;
  @tracked editingAppId = null;
  @tracked editName = "";
  @tracked editDescription = "";
  @tracked editRedirectUris = "";
  @tracked visibleSecretId = null;
  @tracked confirmAction = null;
  @tracked confirmMessage = "";
  @tracked copyFeedback = null;
  @tracked authPage = 1;
  @tracked authTotal = 0;
  @tracked authPerPage = 20;

  // DeepLX API Key state
  @tracked deeplxKey = null;
  @tracked deeplxLoading = true;
  @tracked deeplxError = null;
  @tracked deeplxKeyVisible = false;
  @tracked deeplxSuccess = null;

  constructor() {
    super(...arguments);
    this.loadApps();
    this.loadAuthorizations();
    if (this.siteSettings.sparkloc_deeplx_enabled) {
      this.loadDeeplxKey();
    }
  }

  get deeplxEnabled() {
    return this.siteSettings.sparkloc_deeplx_enabled;
  }

  async loadDeeplxKey() {
    this.deeplxLoading = true;
    try {
      const data = await ajax("/sparkloc/deeplx/key.json");
      this.deeplxKey = data.key !== null && data.key !== undefined ? data : null;
    } catch (_) {
      this.deeplxKey = null;
    } finally {
      this.deeplxLoading = false;
    }
  }

  @action async initDeeplxKey() {
    this.deeplxError = null;
    this.deeplxSuccess = null;
    try {
      const data = await ajax("/sparkloc/deeplx/key/init.json", { type: "POST" });
      this.deeplxKey = data;
      this.deeplxKeyVisible = true;
      this.deeplxSuccess = i18n("sparkloc.deeplx.init_success");
      setTimeout(() => { this.deeplxSuccess = null; }, 3000);
    } catch (e) {
      this.deeplxError = e.jqXHR?.responseJSON?.error || i18n("sparkloc.deeplx.error");
    }
  }

  @action requestDeeplxReset() {
    this.confirmMessage = i18n("sparkloc.deeplx.reset_confirm");
    this.confirmAction = () => this.doDeeplxReset();
  }

  async doDeeplxReset() {
    this.deeplxError = null;
    this.deeplxSuccess = null;
    try {
      const data = await ajax("/sparkloc/deeplx/key/reset.json", { type: "POST" });
      this.deeplxKey = data;
      this.deeplxKeyVisible = true;
      this.deeplxSuccess = i18n("sparkloc.deeplx.reset_success");
      setTimeout(() => { this.deeplxSuccess = null; }, 3000);
    } catch (e) {
      this.deeplxError = e.jqXHR?.responseJSON?.error || i18n("sparkloc.deeplx.error");
    }
  }

  @action toggleDeeplxKeyVisible() {
    this.deeplxKeyVisible = !this.deeplxKeyVisible;
  }

  get isDeeplxBanned() {
    return this.deeplxKey?.status === "banned";
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
      const data = await ajax(`/sparkloc/authorizations.json?page=${this.authPage}&per_page=${this.authPerPage}`);
      this.authorizations = data.authorizations || [];
      this.authTotal = data.total || 0;
    } catch (_) { /* ignore */ }
    finally { this.loadingAuths = false; }
  }

  @action toggleCreate() {
    this.showCreate = !this.showCreate;
    this.editingAppId = null;
    this.error = null;
  }
  @action updateName(e) { this.newName = e.target.value; }
  @action updateDescription(e) { this.newDescription = e.target.value; }
  @action updateRedirectUris(e) { this.newRedirectUris = e.target.value; }
  @action updateEditName(e) { this.editName = e.target.value; }
  @action updateEditDescription(e) { this.editDescription = e.target.value; }
  @action updateEditRedirectUris(e) { this.editRedirectUris = e.target.value; }
  @action dismissCreated() { this.createdApp = null; }
  @action dismissReset() { this.resetResult = null; }

  @action startEdit(app) {
    this.editingAppId = app.id;
    this.editName = app.name;
    this.editDescription = app.description || "";
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
        data: { name: this.editName, description: this.editDescription, redirect_uris: this.editRedirectUris },
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
        data: { name: this.newName, description: this.newDescription, redirect_uris: this.newRedirectUris },
      });
      this.createdApp = result;
      this.newName = "";
      this.newDescription = "";
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

  @action async prevAuthPage() {
    if (this.authPage > 1) {
      this.authPage--;
      await this.loadAuthorizations();
    }
  }

  @action async nextAuthPage() {
    if (this.authPage * this.authPerPage < this.authTotal) {
      this.authPage++;
      await this.loadAuthorizations();
    }
  }

  get appsWithState() {
    return this.apps.map((app) => ({
      ...app,
      isEditing: app.id === this.editingAppId,
      isSecretVisible: app.id === this.visibleSecretId,
    }));
  }

  get authsFormatted() {
    return this.authorizations.map((a) => {
      let statusText, statusClass;
      if (a.status === "approved") {
        statusText = "已授权";
        statusClass = "status-approved";
      } else if (a.status === "denied") {
        statusText = "已拒绝";
        statusClass = "status-denied";
      } else if (a.status === "revoked") {
        statusText = "已撤销";
        statusClass = "status-revoked";
      } else {
        statusText = a.status;
        statusClass = "";
      }
      return { ...a, statusText, statusClass };
    });
  }

  get hasNextAuthPage() {
    return this.authPage * this.authPerPage < this.authTotal;
  }

  get hasPrevAuthPage() {
    return this.authPage > 1;
  }

  get showAuthPagination() {
    return this.hasPrevAuthPage || this.hasNextAuthPage;
  }

  <template>
    <div class="sparkloc-oauth-apps-page">

      {{!-- 复制成功提示 --}}
      {{#if this.copyFeedback}}
        <div class="copy-toast">已复制到剪贴板</div>
      {{/if}}

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

      {{#if this.currentUser.admin}}
        <div class="oauth-actions-bar">
          <a href="/oauth-apps-admin" class="btn btn-default btn-small">管理所有应用</a>
        </div>
      {{/if}}

      {{!-- DeepLX API Key Section --}}
      {{#if this.deeplxEnabled}}
        <div class="deeplx-section">
          <div class="deeplx-header">
            <h3>{{i18n "sparkloc.deeplx.title"}}</h3>
          </div>

          {{#if this.deeplxSuccess}}
            <div class="deeplx-success-notice">{{this.deeplxSuccess}}</div>
          {{/if}}

          {{#if this.deeplxError}}
            <div class="oauth-error-notice">{{this.deeplxError}}</div>
          {{/if}}

          {{#if this.deeplxLoading}}
            <p class="loading-text">{{i18n "sparkloc.upgrade_progress.loading"}}</p>
          {{else if this.deeplxKey}}
            {{#if this.isDeeplxBanned}}
              <div class="deeplx-banned-notice">{{i18n "sparkloc.deeplx.banned_notice"}}</div>
            {{/if}}

            <div class="deeplx-key-card">
              <div class="app-card-field">
                <span class="field-label">API Key</span>
                {{#if this.deeplxKeyVisible}}
                  <code>{{this.deeplxKey.key}}</code>
                {{else}}
                  <code class="secret-masked">••••••••••••••••••••••••</code>
                {{/if}}
                <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" this.toggleDeeplxKeyVisible}} title="显示/隐藏">
                  {{#if this.deeplxKeyVisible}}
                    <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 512"><path fill="currentColor" d="M38.8 5.1C28.4-3.1 13.3-1.2 5.1 9.2s-6.3 25.5 4.1 33.7l592 464c10.4 8.2 25.5 6.3 33.7-4.1s6.3-25.5-4.1-33.7L525.6 386.7c39.6-40.6 66.4-86.1 79.9-118.4c3.3-7.9 3.3-16.7 0-24.6C548.9 69 421.1 0 320 0c-65.2 0-118.8 29.6-159.9 67.7L38.8 5.1zM223.1 149.5C248.6 126.2 282.7 112 320 112c79.5 0 144 64.5 144 144c0 24.9-6.3 48.3-17.4 68.7L223.1 149.5zM166.6 469.7C194.5 488.4 255.8 512 320 512c80.8 0 145.5-36.8 192.6-80.6c46.8-43.5 78.1-95.4 93-131.1c3.3-7.9 3.3-16.7 0-24.6c-14.9-35.7-46.2-87.7-93-131.1l-41.2 32.3C494.8 198.6 512 225.7 512 256c0 79.5-64.5 144-144 144c-26.9 0-52.1-7.4-73.7-20.3L166.6 469.7z"/></svg>
                  {{else}}
                    <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 576 512"><path fill="currentColor" d="M288 32c-80.8 0-145.5 36.8-192.6 80.6C48.6 156 17.3 208 2.5 243.7c-3.3 7.9-3.3 16.7 0 24.6C17.3 304 48.6 356 95.4 399.4C142.5 443.2 207.2 480 288 480s145.5-36.8 192.6-80.6c46.8-43.5 78.1-95.4 93-131.1c3.3-7.9 3.3-16.7 0-24.6c-14.9-35.7-46.2-87.7-93-131.1C433.5 68.8 368.8 32 288 32zM144 256a144 144 0 1 1 288 0 144 144 0 1 1-288 0zm144-64a64 64 0 1 0 0 128 64 64 0 1 0 0-128z"/></svg>
                  {{/if}}
                </button>
                {{#if this.deeplxKeyVisible}}
                  <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.deeplxKey.key)}} title="复制">
                    <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
                  </button>
                {{/if}}
              </div>

              <div class="deeplx-meta">
                <span class="deeplx-status {{if this.isDeeplxBanned "banned" "active"}}">
                  {{if this.isDeeplxBanned (i18n "sparkloc.deeplx.status_banned") (i18n "sparkloc.deeplx.status_active")}}
                </span>
                <span class="deeplx-usage">{{i18n "sparkloc.deeplx.usage_3h"}}: {{this.deeplxKey.usage_3h}}</span>
              </div>

              <div class="deeplx-endpoint-hint">
                <code>{{i18n "sparkloc.deeplx.endpoint_example"}}</code>
              </div>

              {{#unless this.isDeeplxBanned}}
                <div class="card-actions">
                  <button class="btn btn-default btn-small" type="button" {{on "click" this.requestDeeplxReset}}>{{i18n "sparkloc.deeplx.reset"}}</button>
                </div>
              {{/unless}}
            </div>
          {{else}}
            <div class="deeplx-key-card deeplx-empty">
              <p>{{i18n "sparkloc.deeplx.no_key"}}</p>
              <p class="deeplx-endpoint-hint"><code>{{i18n "sparkloc.deeplx.endpoint_example"}}</code></p>
              <button class="btn btn-primary" type="button" {{on "click" this.initDeeplxKey}}>{{i18n "sparkloc.deeplx.init"}}</button>
            </div>
          {{/if}}
        </div>
      {{/if}}

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
            <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.createdApp.client_id)}} title="复制">
              <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
            </button>
          </div>
          <div class="credential-row">
            <span class="credential-label">Client Secret</span>
            <code class="credential-value secret">{{this.createdApp.client_secret}}</code>
            <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.createdApp.client_secret)}} title="复制">
              <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
            </button>
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
            <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.resetResult.client_id)}} title="复制">
              <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
            </button>
          </div>
          <div class="credential-row">
            <span class="credential-label">新 Secret</span>
            <code class="credential-value secret">{{this.resetResult.client_secret}}</code>
            <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText this.resetResult.client_secret)}} title="复制">
              <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
            </button>
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
            <label for="app-desc">应用描述</label>
            <textarea id="app-desc" rows="2" value={{this.newDescription}} {{on "input" this.updateDescription}} placeholder="简要描述你的应用用途（选填）"></textarea>
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
                  <label>描述</label>
                  <textarea rows="2" value={{this.editDescription}} {{on "input" this.updateEditDescription}} placeholder="简要描述你的应用用途（选填）"></textarea>
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
                {{#if app.description}}
                  <div class="app-description">{{app.description}}</div>
                {{/if}}
                <div class="app-card-field">
                  <span class="field-label">Client ID</span>
                  <code>{{app.client_id}}</code>
                  <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText app.client_id)}} title="复制">
                    <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
                  </button>
                </div>
                <div class="app-card-field">
                  <span class="field-label">Client Secret</span>
                  {{#if app.isSecretVisible}}
                    <code>{{app.client_secret}}</code>
                  {{else}}
                    <code class="secret-masked">••••••••••••••••</code>
                  {{/if}}
                  <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.toggleSecret app.id)}} title="显示/隐藏">
                    {{#if app.isSecretVisible}}
                      <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 512"><path fill="currentColor" d="M38.8 5.1C28.4-3.1 13.3-1.2 5.1 9.2s-6.3 25.5 4.1 33.7l592 464c10.4 8.2 25.5 6.3 33.7-4.1s6.3-25.5-4.1-33.7L525.6 386.7c39.6-40.6 66.4-86.1 79.9-118.4c3.3-7.9 3.3-16.7 0-24.6C548.9 69 421.1 0 320 0c-65.2 0-118.8 29.6-159.9 67.7L38.8 5.1zM223.1 149.5C248.6 126.2 282.7 112 320 112c79.5 0 144 64.5 144 144c0 24.9-6.3 48.3-17.4 68.7L223.1 149.5zM166.6 469.7C194.5 488.4 255.8 512 320 512c80.8 0 145.5-36.8 192.6-80.6c46.8-43.5 78.1-95.4 93-131.1c3.3-7.9 3.3-16.7 0-24.6c-14.9-35.7-46.2-87.7-93-131.1l-41.2 32.3C494.8 198.6 512 225.7 512 256c0 79.5-64.5 144-144 144c-26.9 0-52.1-7.4-73.7-20.3L166.6 469.7z"/></svg>
                    {{else}}
                      <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 576 512"><path fill="currentColor" d="M288 32c-80.8 0-145.5 36.8-192.6 80.6C48.6 156 17.3 208 2.5 243.7c-3.3 7.9-3.3 16.7 0 24.6C17.3 304 48.6 356 95.4 399.4C142.5 443.2 207.2 480 288 480s145.5-36.8 192.6-80.6c46.8-43.5 78.1-95.4 93-131.1c3.3-7.9 3.3-16.7 0-24.6c-14.9-35.7-46.2-87.7-93-131.1C433.5 68.8 368.8 32 288 32zM144 256a144 144 0 1 1 288 0 144 144 0 1 1-288 0zm144-64a64 64 0 1 0 0 128 64 64 0 1 0 0-128z"/></svg>
                    {{/if}}
                  </button>
                  {{#if app.isSecretVisible}}
                    <button class="btn btn-flat btn-small btn-icon-action" type="button" {{on "click" (fn this.copyText app.client_secret)}} title="复制">
                      <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M384 336H192c-8.8 0-16-7.2-16-16V64c0-8.8 7.2-16 16-16l140.1 0L400 115.9V320c0 8.8-7.2 16-16 16zM192 384h192c35.3 0 64-28.7 64-64V115.9c0-12.7-5.1-24.9-14.1-33.9L366 14.1c-9-9-21.2-14.1-33.9-14.1H192c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64zM64 128c-35.3 0-64 28.7-64 64v256c0 35.3 28.7 64 64 64h192c35.3 0 64-28.7 64-64v-32h-48v32c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V192c0-8.8 7.2-16 16-16h32v-48H64z"/></svg>
                    </button>
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
      <p class="auth-retention-note">授权记录保留 7 天</p>

      {{#if this.loadingAuths}}
        <p class="loading-text">加载中...</p>
      {{else if this.authsFormatted.length}}
        <div class="auth-list-table">
          <div class="auth-list-header">
            <span class="auth-col-name">应用</span>
            <span class="auth-col-time">授权时间</span>
            <span class="auth-col-status">状态</span>
          </div>
          {{#each this.authsFormatted as |auth|}}
            <div class="auth-list-row">
              <span class="auth-col-name">
                <span class="auth-app-name">{{auth.app_name}}</span>
                {{#if auth.scope}}
                  <span class="auth-scope">{{auth.scope}}</span>
                {{/if}}
              </span>
              <span class="auth-col-time">{{auth.created_at}}</span>
              <span class="auth-col-status">
                <span class="auth-status-badge {{auth.statusClass}}">{{auth.statusText}}</span>
              </span>
            </div>
          {{/each}}
        </div>
        {{#if this.showAuthPagination}}
          <div class="auth-pagination">
            <button class="btn btn-default btn-small" type="button" {{on "click" this.prevAuthPage}}>上一页</button>
            <span class="auth-page-info">第 {{this.authPage}} 页</span>
            <button class="btn btn-default btn-small" type="button" {{on "click" this.nextAuthPage}}>下一页</button>
          </div>
        {{/if}}
      {{else}}
        <p class="no-apps-text">暂无授权记录。</p>
      {{/if}}

    </div>
  </template>
}

export default RouteTemplate(<template><OauthAppsPage /></template>);
