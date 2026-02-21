import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class UserBillingRoute extends Route {
  @service router;

  beforeModel() {
    this.router.replaceWith("user.billing.subscriptions");
  }
}
