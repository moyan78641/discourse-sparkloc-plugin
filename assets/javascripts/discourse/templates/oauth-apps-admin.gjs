import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";

class OauthAppsAdminPage extends Component {
  @tracked apps = [];
  @tracked loading = true;
  @tracked error = null;
  @tracked editingAppId = null;
  @tracked editName = "";
  @tracked editDescription = "";
  @tracked editRedirectUris = "";
  @tracked confirmAction = null;
  @tracked confirmMessage = "";
  @tracked copyFeedback = null;

  constructor() {
    super(...arguments);
    this.loadApps();
  }

  async loadApps() {
    try {
      const data = await ajax("/sparkloc/admin/apps.json");
      this.apps = data.apps || [];
    } catch (e) {
      this.error = "加载失败";
    } finally {
      this.loading = false;
    }
  }

  @action startEdit(app) {
    this.editingAppId = app.id;
    this.editName = app.name;
    this.editDescription = app.description || "";
    this.editRedirectUris = app.redirect_uris;
    this.error = null;
  }

  @action cancelEdit() { this.editingAppId = null; }
  @action updateEditName(e) { this.editName = e.target.value; }
  @action updateEditDescription(e) { this.editDescription = e.target.value; }
  @action updateEditRedirectUris(e) { this.editRedirectUris = e.target.value; }

  @action async saveEdit(appId) {
    this.error = null;
    try {
      await ajax(`/sparkloc/admin/apps/${appId}.json`, {
        type: "PUT",
        data: { name: this.editName, description: this.editDescription, redirect_uris: this.editRedirectUris },
      });
      this.editingAppId = null;
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "修改失败";
    }
  }

  @action requestDelete(appId) {
    this.confirmMessage = "确定删除此应用？删除后不可恢复。";
    this.confirmAction = () => this.doDelete(appId);
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
      await ajax(`/sparkloc/admin/apps/${appId}.json`, { type: "DELETE" });
      await this.loadApps();
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.error || "删除失败";
    }
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
    }));
  }

  <template>
    <div class="sparkloc-oauth-apps-page">

      {{#if this.copyFeedback}}
        <div class="copy-toast">已复制到剪贴板</div>
      {{/if}}

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

      <h2>OAuth 应用管理（管理员）</h2>

      {{#if this.error}}
        <div class="oauth-error-notice">{{this.error}}</div>
      {{/if}}

      {{#if this.loading}}
        <p class="loading-text">加载中...</p>
      {{else if this.apps.length}}
        <div class="admin-apps-table">
          <div class="admin-apps-header">
            <span class="admin-col-id">ID</span>
            <span class="admin-col-user">用户</span>
            <span class="admin-col-name">应用名称</span>
            <span class="admin-col-desc">描述</span>
            <span class="admin-col-uri">回调地址</span>
            <span class="admin-col-actions">操作</span>
          </div>
          {{#each this.appsWithState as |app|}}
            {{#if app.isEditing}}
              <div class="admin-apps-row editing">
                <div class="admin-edit-form">
                  <div class="form-row">
                    <label>名称</label>
                    <input type="text" value={{this.editName}} {{on "input" this.updateEditName}} />
                  </div>
                  <div class="form-row">
                    <label>描述</label>
                    <textarea rows="2" value={{this.editDescription}} {{on "input" this.updateEditDescription}}></textarea>
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
              </div>
            {{else}}
              <div class="admin-apps-row">
                <span class="admin-col-id">{{app.id}}</span>
                <span class="admin-col-user">
                  <a href="/u/{{app.owner_username}}">@{{app.owner_username}}</a>
                </span>
                <span class="admin-col-name">{{app.name}}</span>
                <span class="admin-col-desc">{{app.description}}</span>
                <span class="admin-col-uri admin-uri-text">{{app.redirect_uris}}</span>
                <span class="admin-col-actions">
                  <button class="btn btn-default btn-small" type="button" {{on "click" (fn this.startEdit app)}}>修改</button>
                  <button class="btn btn-danger btn-small" type="button" {{on "click" (fn this.requestDelete app.id)}}>删除</button>
                </span>
              </div>
            {{/if}}
          {{/each}}
        </div>
      {{else}}
        <p class="no-apps-text">暂无应用。</p>
      {{/if}}

    </div>
  </template>
}

export default RouteTemplate(<template><OauthAppsAdminPage /></template>);
