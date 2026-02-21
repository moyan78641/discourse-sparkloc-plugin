import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class UserBillingSubscriptionsRoute extends Route {
  model() {
    return ajax("/sparkloc/creem/subscription.json");
  }
}
