import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

const BillingTab = <template>
  <li>
    <LinkTo @route="user.billing" @model={{@outletArgs.model}}>
      {{i18n "sparkloc.billing.title"}}
    </LinkTo>
  </li>
</template>;

export default BillingTab;
