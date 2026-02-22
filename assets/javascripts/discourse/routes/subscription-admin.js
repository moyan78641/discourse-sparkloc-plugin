import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class SubscriptionAdminRoute extends Route {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.admin) {
      this.router.replaceWith("discovery.latest");
    }
  }

  model() {
    return ajax("/sparkloc/admin/subscriptions.json");
  }
}
