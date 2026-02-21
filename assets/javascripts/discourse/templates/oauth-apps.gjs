import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";

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

  @action cancelEdit() {
    this.editingAppId = null;
  }

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

  @action async deleteApp(appId) {
    if (!confirm("确定删除此应用？")) return;
    try {
      await ajax(`/sparkloc/apps/${appId}.json`, { type: "DELETE" });
      this.createdApp = null;
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "删除失败";
    }
  }

  @action async resetSecret(appId) {
    if (!confirm("确定重置密钥？旧密钥将立即失效。")) return;
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

  get appsWithState() {
    return this.apps.map((app) => ({
      ...app,
      isEditing: app.id === this.editingAppId,
      isSecretVisible: app.id === this.visibleSecretId,
    }));
  }

  <template>
    <div class="sparkloc-oauth-apps-page">

      <h2>我的应用</h2>

      {{#if this.createdApp}}
        <div class="oauth-credential-notice">
          <h3>应用创建成功</h3>
          <p class="warning-text">请立即保存 Client Secret，关闭后将无法再次查看。</p>
          <div class="credential-row">
            <span class="credential-label">Client ID</span>
            <code class="credential-value">{{this.createdApp.client_id}}</code>
          </div>
          <div class="credential-row">
            <span class="credential-label">Client Secret</span>
            <code class="credential-value secret">{{this.createdApp.client_secret}}</code>
          </div>
          <button class="btn btn-default" type="button" {{on "click" this.dismissCreated}}>知道了</button>
        </div>
      {{/if}}

      {{#if this.resetResult}}
        <div class="oauth-credential-notice">
          <h3>密钥已重置</h3>
          <p class="warning-text">请立即保存新的 Client Secret，关闭后将无法再次查看。</p>
          <div class="credential-row">
            <span class="credential-label">Client ID</span>
            <code class="credential-value">{{this.resetResult.client_id}}</code>
          </div>
          <div class="credential-row">
            <span class="credential-label">新 Secret</span>
            <code class="credential-value secret">{{this.resetResult.client_secret}}</code>
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
        <table class="oauth-apps-table">
          <thead>
            <tr>
              <th>名称</th>
              <th>Client ID</th>
              <th>Client Secret</th>
              <th>回调地址</th>
              <th>创建时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.appsWithState as |app|}}
              {{#if app.isEditing}}
                <tr class="editing-row">
                  <td><input type="text" value={{this.editName}} {{on "input" this.updateEditName}} /></td>
                  <td><code>{{app.client_id}}</code></td>
                  <td><code class="secret-masked">••••••••</code></td>
                  <td><input type="text" value={{this.editRedirectUris}} {{on "input" this.updateEditRedirectUris}} /></td>
                  <td>{{app.created_at}}</td>
                  <td class="actions-cell">
                    <button class="btn btn-primary btn-small" type="button" {{on "click" (fn this.saveEdit app.id)}}>保存</button>
                    <button class="btn btn-default btn-small" type="button" {{on "click" this.cancelEdit}}>取消</button>
                  </td>
                </tr>
              {{else}}
                <tr>
                  <td>{{app.name}}</td>
                  <td><code>{{app.client_id}}</code></td>
                  <td class="secret-cell">
                    {{#if app.isSecretVisible}}
                      <code>{{app.client_secret}}</code>
                    {{else}}
                      <code class="secret-masked">••••••••••••</code>
                    {{/if}}
                    <button class="btn btn-flat btn-icon btn-small secret-toggle" type="button" {{on "click" (fn this.toggleSecret app.id)}} title="显示/隐藏密钥">
                      {{#if app.isSecretVisible}}🙈{{else}}👁{{/if}}
                    </button>
                  </td>
                  <td class="redirect-uri-cell">{{app.redirect_uris}}</td>
                  <td>{{app.created_at}}</td>
                  <td class="actions-cell">
                    <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.startEdit app)}}>编辑</button>
                    <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.resetSecret app.id)}}>重置密钥</button>
                    <button class="btn btn-danger btn-small" type="button" {{on "click" (fn this.deleteApp app.id)}}>删除</button>
                  </td>
                </tr>
              {{/if}}
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="no-apps-text">您还没有创建应用。</p>
      {{/if}}

      <h2 class="section-title">已授权的应用</h2>

      {{#if this.loadingAuths}}
        <p class="loading-text">加载中...</p>
      {{else if this.authorizations.length}}
        <table class="oauth-apps-table">
          <thead>
            <tr>
              <th>应用名称</th>
              <th>授权时间</th>
              <th>状态</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.authorizations as |auth|}}
              <tr>
                <td>{{auth.app_name}}</td>
                <td>{{auth.created_at}}</td>
                <td>{{auth.statusText}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="no-apps-text">暂无已授权的应用。</p>
      {{/if}}

    </div>
  </template>
}

export default RouteTemplate(<template><OauthAppsPage /></template>);
