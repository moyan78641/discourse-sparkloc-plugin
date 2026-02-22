import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class UserBillingSubscriptionsRoute extends Route {
  @service currentUser;
  @service router;

  beforeModel() {
    // 只允许查看自己的订阅
    const user = this.modelFor("user");
    if (!this.currentUser || user.username !== this.currentUser.username) {
      this.router.replaceWith("user.summary");
    }
  }

  model() {
    return ajax("/sparkloc/creem/subscription.json");
  }
}
