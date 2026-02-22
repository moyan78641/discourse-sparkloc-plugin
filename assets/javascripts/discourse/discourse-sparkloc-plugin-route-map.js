export default function () {
  this.route("merchants", { path: "/merchants" });
  this.route("oauth-apps", { path: "/oauth-apps" });
  this.route("oauth-apps-admin", { path: "/oauth-apps-admin" });
  this.route("lottery", { path: "/lottery" });
  this.route("subscription-admin", { path: "/subscription-admin" });
}
