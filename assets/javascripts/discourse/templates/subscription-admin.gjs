import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { helper } from "@ember/component/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const formatDate = helper(function ([dateStr]) {
  if (!dateStr) return "-";
  return new Date(dateStr).toLocaleDateString();
});

const sourceLabel = helper(function ([source]) {
  return source === "manual" ? "手动" : "Creem";
});

const statusLabel = helper(function ([status]) {
  const map = { active: "活跃", canceled: "已取消", expired: "已过期", trialing: "试用中", paused: "已暂停", refunded: "已退款" };
  return map[status] || status;
});

class SubscriptionAdminPage extends Component {
  @tracked subscriptions = this.args.model?.subscriptions || [];
  @tracked newUsername = "";
  @tracked newMonths = 1;
  @tracked renewMonths = 1;
  @tracked loading = false;
  @tracked message = null;

  @action
  updateNewUsername(e) {
    this.newUsername = e.target.value;
  }

  @action
  updateNewMonths(e) {
    this.newMonths = parseInt(e.target.value, 10) || 1;
  }

  @action
  updateRenewMonths(e) {
    this.renewMonths = parseInt(e.target.value, 10) || 1;
  }

  @action
  async addSubscription() {
    if (!this.newUsername.trim()) return;
    this.loading = true;
    this.message = null;
    try {
      const result = await ajax("/sparkloc/admin/subscriptions.json", {
        type: "POST",
        data: { username: this.newUsername.trim(), months: this.newMonths },
      });
      this.message = `已为 ${this.newUsername} 添加订阅，到期: ${new Date(result.period_end).toLocaleDateString()}`;
      this.newUsername = "";
      this.newMonths = 1;
      await this.reload();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async renewSubscription(username) {
    this.loading = true;
    this.message = null;
    try {
      const result = await ajax("/sparkloc/admin/subscriptions/renew.json", {
        type: "PUT",
        data: { username, months: this.renewMonths },
      });
      this.message = `已为 ${username} 续费，新到期: ${new Date(result.period_end).toLocaleDateString()}`;
      await this.reload();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async cancelSubscription(username) {
    if (!confirm(`确定取消 ${username} 的订阅？将立即移出订阅组。`)) return;
    this.loading = true;
    this.message = null;
    try {
      await ajax("/sparkloc/admin/subscriptions.json", {
        type: "DELETE",
        data: { username },
      });
      this.message = `已取消 ${username} 的订阅`;
      await this.reload();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  async reload() {
    try {
      const data = await ajax("/sparkloc/admin/subscriptions.json");
      this.subscriptions = data.subscriptions || [];
    } catch (e) {
      // ignore
    }
  }

  <template>
    <div class="subscription-admin-page">
      <h2>订阅管理</h2>

      {{#if this.message}}
        <div class="alert alert-info">{{this.message}}</div>
      {{/if}}

      <div class="subscription-admin-add" style="margin-bottom:20px;padding:15px;background:var(--primary-very-low);border-radius:8px;">
        <h3>手动添加订阅</h3>
        <div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;">
          <input
            type="text"
            placeholder="用户名"
            value={{this.newUsername}}
            {{on "input" this.updateNewUsername}}
            style="padding:6px 10px;border:1px solid var(--primary-low);border-radius:4px;width:180px;"
          />
          <label>月数:</label>
          <input
            type="number"
            min="1"
            value={{this.newMonths}}
            {{on "input" this.updateNewMonths}}
            style="padding:6px 10px;border:1px solid var(--primary-low);border-radius:4px;width:70px;"
          />
          <button
            class="btn btn-primary"
            type="button"
            disabled={{this.loading}}
            {{on "click" this.addSubscription}}
          >添加</button>
        </div>
      </div>

      <div class="subscription-admin-renew-config" style="margin-bottom:15px;display:flex;gap:10px;align-items:center;">
        <label>续费月数:</label>
        <input
          type="number"
          min="1"
          value={{this.renewMonths}}
          {{on "input" this.updateRenewMonths}}
          style="padding:6px 10px;border:1px solid var(--primary-low);border-radius:4px;width:70px;"
        />
      </div>

      <table class="subscription-admin-table" style="width:100%;border-collapse:collapse;">
        <thead>
          <tr style="border-bottom:2px solid var(--primary-low);">
            <th style="text-align:left;padding:8px;">用户</th>
            <th style="text-align:left;padding:8px;">状态</th>
            <th style="text-align:left;padding:8px;">来源</th>
            <th style="text-align:left;padding:8px;">到期时间</th>
            <th style="text-align:left;padding:8px;">操作</th>
          </tr>
        </thead>
        <tbody>
          {{#each this.subscriptions as |sub|}}
            <tr style="border-bottom:1px solid var(--primary-low);">
              <td style="padding:8px;">{{sub.username}}</td>
              <td style="padding:8px;">{{statusLabel sub.status}}</td>
              <td style="padding:8px;">{{sourceLabel sub.source}}</td>
              <td style="padding:8px;">{{formatDate sub.current_period_end}}</td>
              <td style="padding:8px;display:flex;gap:6px;">
                <button
                  class="btn btn-small btn-primary"
                  type="button"
                  disabled={{this.loading}}
                  {{on "click" (fn this.renewSubscription sub.username)}}
                >续费</button>
                <button
                  class="btn btn-small btn-danger"
                  type="button"
                  disabled={{this.loading}}
                  {{on "click" (fn this.cancelSubscription sub.username)}}
                >取消</button>
              </td>
            </tr>
          {{else}}
            <tr>
              <td colspan="5" style="padding:20px;text-align:center;color:var(--primary-medium);">暂无订阅记录</td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}

export default RouteTemplate(SubscriptionAdminPage);
