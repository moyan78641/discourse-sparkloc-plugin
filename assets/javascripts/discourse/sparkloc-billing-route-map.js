export default {
  resource: "user",
  map() {
    this.route("billing", function () {
      this.route("subscriptions");
    });
  },
};
