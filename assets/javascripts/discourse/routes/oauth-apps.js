import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class OauthAppsRoute extends Route {
  model() {
    return ajax("/sparkloc/apps.json");
  }
}
