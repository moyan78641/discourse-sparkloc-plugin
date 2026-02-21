import Route from "@ember/routing/route";

export default class UserBillingRoute extends Route {
  beforeModel() {
    this.replaceWith("user.billing.subscriptions");
  }
}
