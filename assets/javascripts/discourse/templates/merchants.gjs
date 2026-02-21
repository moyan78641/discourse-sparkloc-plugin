import RouteTemplate from "ember-route-template";

export default RouteTemplate(
  <template>
    <div class="sparkloc-merchants-page">
      <h2>认证商家</h2>
      <div class="merchants-grid">
        {{#each @model.merchants as |merchant|}}
          <div class="merchant-card">
            <div class="merchant-card-inner">
              <div class="merchant-card-front">
                {{#if merchant.logo_url}}
                  <img
                    class="merchant-logo"
                    src={{merchant.logo_url}}
                    alt={{merchant.name}}
                    loading="lazy"
                  />
                {{else}}
                  <div class="merchant-logo-placeholder">
                    {{merchant.name}}
                  </div>
                {{/if}}
              </div>
              <div class="merchant-card-back">
                <h3 class="merchant-name">{{merchant.name}}</h3>
                {{#if merchant.description}}
                  <p class="merchant-desc">{{merchant.description}}</p>
                {{/if}}
                {{#if merchant.website}}
                  <a
                    class="merchant-link"
                    href={{merchant.website}}
                    target="_blank"
                    rel="noopener noreferrer"
                  >官网</a>
                {{/if}}
                {{#if merchant.discourse_username}}
                  <a
                    class="merchant-link"
                    href="/u/{{merchant.discourse_username}}"
                  >论坛主页</a>
                {{/if}}
              </div>
            </div>
          </div>
        {{/each}}
      </div>
    </div>
  </template>
);
