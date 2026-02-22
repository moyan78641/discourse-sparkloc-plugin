import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class OauthAppsAdminRoute extends Route {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.admin) {
      this.router.replaceWith("discovery.latest");
    }
  }
}
