import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";
import { service } from "@ember/service";
import Component from "@glimmer/component";

class BillingTab extends Component {
  @service currentUser;

  get isOwnProfile() {
    return this.currentUser && this.args.outletArgs?.model?.username === this.currentUser.username;
  }

  <template>
    {{#if this.isOwnProfile}}
      <li>
        <LinkTo @route="user.billing" @model={{@outletArgs.model}}>
          <svg class="fa d-icon d-icon-credit-card svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#credit-card"></use></svg>
          <span>{{i18n "sparkloc.billing.title"}}</span>
        </LinkTo>
      </li>
    {{/if}}
  </template>
}

export default BillingTab;
