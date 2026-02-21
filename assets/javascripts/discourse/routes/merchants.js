import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class MerchantsRoute extends Route {
  model() {
    return ajax("/sparkloc/merchants.json");
  }
}
