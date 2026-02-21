import RouteTemplate from "ember-route-template";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

class SubscriptionPage extends Component {
  @tracked canceling = false;
  @tracked subscribing = false;
  @tracked message = null;
  @tracked messageType = null;

  get subscription() {
    return this.args.model;
  }

  get isNone() {
    return !this.subscription || this.subscription.status === "none";
  }

  get isActive() {
    return this.subscription?.status === "active" || this.subscription?.status === "trialing";
  }

  get isCanceled() {
    return this.subscription?.status === "canceled";
  }

  get isTerminated() {
    const s = this.subscription?.status;
    return s === "expired" || s === "paused" || s === "refunded";
  }

  get statusLabel() {
    const s = this.subscription?.status;
    if (!s || s === "none") return i18n("sparkloc.billing.status_none");
    return i18n(`sparkloc.billing.status_${s}`);
  }

  get formattedPeriodEnd() {
    const d = this.subscription?.current_period_end;
    if (!d) return null;
    return new Date(d).toLocaleDateString();
  }

  @action
  async subscribe() {
    this.subscribing = true;
    this.message = null;
    try {
      const result = await ajax("/sparkloc/creem/checkout.json", { type: "POST" });
      if (result.checkout_url) {
        window.location.href = result.checkout_url;
      }
    } catch (e) {
      this.message = i18n("sparkloc.billing.checkout_error");
      this.messageType = "error";
    } finally {
      this.subscribing = false;
    }
  }

  @action
  async cancelSubscription() {
    if (!confirm(i18n("sparkloc.billing.cancel_confirm"))) return;

    this.canceling = true;
    this.message = null;
    try {
      await ajax("/sparkloc/creem/cancel.json", { type: "POST" });
      this.message = i18n("sparkloc.billing.cancel_success");
      this.messageType = "success";
      // 刷新数据
      const updated = await ajax("/sparkloc/creem/subscription.json");
      Object.assign(this.args.model, updated);
    } catch (e) {
      this.message = i18n("sparkloc.billing.cancel_error");
      this.messageType = "error";
    } finally {
      this.canceling = false;
    }
  }

  @action
  async openBillingPortal() {
    try {
      const result = await ajax("/sparkloc/creem/billing-portal.json", { type: "POST" });
      if (result.url) {
        window.open(result.url, "_blank");
      }
    } catch (e) {
      this.message = i18n("sparkloc.billing.portal_error");
      this.messageType = "error";
    }
  }

  <template>
    <div class="sparkloc-billing-page">
      <h2>{{i18n "sparkloc.billing.subscriptions"}}</h2>

      <div class="sparkloc-guide-box">
        <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#book"></use></svg>
        <div class="guide-content">
          <h3>{{i18n "sparkloc.billing.guide_title"}}</h3>
          <p>{{i18n "sparkloc.billing.guide_desc"}}</p>
          <a href="https://sparkloc.com/t/topic/32" target="_blank" rel="noopener noreferrer" class="btn btn-default">
            {{i18n "sparkloc.billing.guide_btn"}}
            <svg class="fa d-icon svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#external-link-alt"></use></svg>
          </a>
        </div>
      </div>

      {{#if this.message}}
        <div class="billing-message {{this.messageType}}">
          {{this.message}}
        </div>
      {{/if}}

      {{#if this.isNone}}
        <div class="billing-card">
          <p class="billing-desc">{{i18n "sparkloc.billing.subscribe_desc"}}</p>
          <DButton
            @action={{this.subscribe}}
            @label="sparkloc.billing.subscribe"
            @icon="credit-card"
            @disabled={{this.subscribing}}
            class="btn-primary"
          />
        </div>
      {{else if this.isTerminated}}
        <div class="billing-card">
          <div class="billing-status">
            <span class="status-label">{{i18n "sparkloc.billing.status"}}</span>
            <span class="status-value terminated">{{this.statusLabel}}</span>
          </div>
          <p class="billing-desc">{{i18n "sparkloc.billing.subscribe_desc"}}</p>
          <DButton
            @action={{this.subscribe}}
            @label="sparkloc.billing.subscribe"
            @icon="credit-card"
            @disabled={{this.subscribing}}
            class="btn-primary"
          />
        </div>
      {{else}}
        <div class="billing-card">
          <div class="billing-status">
            <span class="status-label">{{i18n "sparkloc.billing.status"}}</span>
            <span class="status-value {{if this.isActive "active" "canceled"}}">{{this.statusLabel}}</span>
          </div>

          {{#if this.formattedPeriodEnd}}
            <div class="billing-period">
              <span class="period-label">{{i18n "sparkloc.billing.period_end"}}</span>
              <span class="period-value">{{this.formattedPeriodEnd}}</span>
            </div>
          {{/if}}

          <div class="billing-actions">
            <DButton
              @action={{this.openBillingPortal}}
              @label="sparkloc.billing.manage"
              @icon="credit-card"
              class="btn-default"
            />
            {{#if this.isActive}}
              <DButton
                @action={{this.cancelSubscription}}
                @label="sparkloc.billing.cancel"
                @disabled={{this.canceling}}
                class="btn-danger"
              />
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}

export default RouteTemplate(SubscriptionPage);
