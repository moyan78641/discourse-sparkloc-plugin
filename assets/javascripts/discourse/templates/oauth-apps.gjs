import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";

class OauthAppsPage extends Component {
  @tracked apps = [];
  @tracked showCreate = false;
  @tracked newName = "";
  @tracked newRedirectUris = "";
  @tracked createdApp = null;
  @tracked error = null;
  @tracked resetResult = null;

  constructor() {
    super(...arguments);
    const model = this.args.model;
    this.apps = model?.apps || [];
  }

  @action toggleCreate() {
    this.showCreate = !this.showCreate;
    this.error = null;
  }

  @action updateName(e) { this.newName = e.target.value; }
  @action updateRedirectUris(e) { this.newRedirectUris = e.target.value; }

  @action dismissCreated() { this.createdApp = null; }
  @action dismissReset() { this.resetResult = null; }

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
      await this.reload();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "创建失败";
    }
  }

  @action async deleteApp(appId) {
    if (!confirm("确定删除此应用？删除后无法恢复。")) return;
    try {
      await ajax(`/sparkloc/apps/${appId}.json`, { type: "DELETE" });
      this.createdApp = null;
      await this.reload();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "删除失败";
    }
  }

  @action async resetSecret(appId) {
    if (!confirm("确定重置密钥？旧密钥将立即失效。")) return;
    try {
      const result = await ajax(`/sparkloc/apps/${appId}/reset-secret.json`, {
        type: "POST",
      });
      this.resetResult = result;
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "重置失败";
    }
  }

  async reload() {
    try {
      const data = await ajax("/sparkloc/apps.json");
      this.apps = data.apps || [];
    } catch (_) { /* ignore */ }
  }

  <template>
    <div class="sparkloc-oauth-apps-page">
      <h2>OAuth2 应用管理</h2>
      <p class="oauth-apps-desc">创建和管理你的 OAuth2 应用，获取 Client ID 和 Client Secret 用于接入 Sparkloc 登录。</p>

      {{#if this.createdApp}}
        <div class="oauth-credential-notice">
          <h3>✅ 应用创建成功</h3>
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
          <h3>🔑 密钥已重置</h3>
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
          {{if this.showCreate "取消" "创建新应用"}}
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

      {{#if this.apps.length}}
        <table class="oauth-apps-table">
          <thead>
            <tr>
              <th>名称</th>
              <th>Client ID</th>
              <th>回调地址</th>
              <th>创建时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.apps as |app|}}
              <tr>
                <td>{{app.name}}</td>
                <td><code>{{app.client_id}}</code></td>
                <td class="redirect-uri-cell">{{app.redirect_uris}}</td>
                <td>{{app.created_at}}</td>
                <td class="actions-cell">
                  <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.resetSecret app.id)}}>重置密钥</button>
                  <button class="btn btn-danger btn-small" type="button" {{on "click" (fn this.deleteApp app.id)}}>删除</button>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="no-apps-text">暂无应用，点击上方按钮创建你的第一个 OAuth2 应用。</p>
      {{/if}}
    </div>
  </template>
}

export default RouteTemplate(<template><OauthAppsPage @model={{@model}} /></template>);
