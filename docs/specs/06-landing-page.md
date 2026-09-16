# 06 — Landing page

A LP não é um arquivo HTML gerado; é uma view Rails renderizada a partir do `Product`.
Padrão **Direct Response**: um único objetivo, o botão de compra.

## Rota e controller

```ruby
get "/:slug", to: "landing_pages#show", as: :landing_page,
    constraints: { slug: /[a-z0-9-]+/ }
```

Declarada **por último** em `routes.rb`, depois de todas as rotas fixas (`/thank-you`, `/download`,
`/access`, `/privacy`, `/terms`, `/refund-policy`, `/admin`, `/checkout`, `/webhooks`), para não capturá-las.
Slugs reservados validados no modelo: `admin, checkout, webhooks, download, thank-you, access, privacy,
terms, refund-policy, up, rails, assets`.

```ruby
class LandingPagesController < ApplicationController
  allow_unauthenticated_access
  before_action :capture_attribution   # ver spec 10

  def show
    @product = Product.published.find_by!(slug: params[:slug])   # 404 se draft/archived
    @tracking = { pixel: true, ga4: true }
    render "landing_pages/templates/#{@product.template}/show"
  end
end
```

`Admin::ProductsController#preview` renderiza o mesmo template com `@preview = true`.

## Estrutura do template `direct_response`

Cada bloco é um partial em `app/views/landing_pages/templates/direct_response/`:

| Ordem | Partial | Conteúdo | Condição |
|---|---|---|---|
| 1 | `_hero` | headline, subheadline, mockup_image, CTA primário (âncora para `#buy`) | sempre |
| 2 | `_problem` | problem_text (identificação com a dor) | se presente |
| 3 | `_benefits` | lista de `benefits` com ícone genérico | sempre (≥1) |
| 4 | `_whats_inside` | description (Action Text) | se presente |
| 5 | `_previews` | galeria de `preview_images` | se ≥1 |
| 6 | `_testimonials` | depoimentos | se ≥1 |
| 7 | `_offer` (`id="buy"`) | preço, compare_at (riscado), campo telefone + opt-in, botão PayPal | sempre |
| 8 | `_guarantee` | guarantee_text + refund_days | se presente |
| 9 | `_faq` | perguntas (`<details>` nativo) | se ≥1 |
| 10 | `_final_cta` | repete promessa + botão que rola para `#buy` | sempre |
| 11 | `_footer` | © , SUPPORT_EMAIL, links Privacy / Terms / Refund Policy | sempre |

Sem menu, sem links externos além do rodapé. Um sticky CTA mobile (barra inferior "Buy Now — $14.90")
DEVERIA aparecer após o usuário rolar além do hero.

## Bloco de oferta (checkout embutido)

```html
<section id="buy"
         data-module="checkout"
         data-product-id="<%= @product.id %>"
         data-paypal-client-id="<%= paypal_client_id %>"
         data-create-url="<%= checkout_paypal_path %>"
         data-capture-url="<%= checkout_paypal_capture_path %>"
         data-whatsapp-enabled="<%= twilio_enabled? %>">
  <p class="price">$14.90 <s>$29.00</s></p>          <!-- valores do backend, formatados -->
  <form>
    <label>Phone (optional) <input type="tel" name="phone" placeholder="+1 555 123 4567" autocomplete="tel"></label>
    <label><input type="checkbox" name="whatsapp_opt_in" value="1"> Send my download link on WhatsApp too</label>
    <p class="hint">Standard messaging rates may apply. Reply STOP to opt out.</p>
    <div id="paypal-button-container"></div>
    <noscript><p>Please enable JavaScript to complete your purchase.</p></noscript>
  </form>
</section>
```

`modules/checkout.js` (JS puro, sem framework):

```js
export function init(el) {
  const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) { io.disconnect(); loadSdk(); } },
                                      { rootMargin: "400px" });
  io.observe(el);

  function loadSdk() {
    const s = document.createElement("script");
    s.src = `https://www.paypal.com/sdk/js?client-id=${el.dataset.paypalClientId}&currency=USD&intent=capture&disable-funding=paylater`;
    s.onload = renderButtons;
    document.head.appendChild(s);
  }

  function renderButtons() {
    window.paypal.Buttons({
      style: { layout: "vertical", label: "pay" },
      onClick: () => tracking.initiateCheckout(el.dataset),
      createOrder: async () => {
        const form = el.querySelector("form");
        const { paypal_order_id } = await http.post(el.dataset.createUrl, {
          product_id: el.dataset.productId,
          phone: form.phone.value,
          whatsapp_opt_in: form.whatsapp_opt_in?.checked ?? false
        });
        return paypal_order_id;
      },
      onApprove: async ({ orderID }) => {
        const { thank_you_url } = await http.post(el.dataset.captureUrl, { paypal_order_id: orderID });
        window.location.assign(thank_you_url);
      },
      onError: (err) => showError(el, "Something went wrong. Please try again or contact support.")
    }).render("#paypal-button-container");
  }
}
```

- SDK carregado sob demanda via `IntersectionObserver` quando a seção se aproxima da viewport.
- `http.post` (em `lib/http.js`) envia JSON + `X-CSRF-Token`. Detalhes do backend em [07-checkout-paypal.md](07-checkout-paypal.md).
- Campo de telefone + opt-in só renderizados quando `TWILIO_ENABLED=true`.
- Checkbox de opt-in **desmarcada por padrão**. Telefone validado no cliente (formato) e no servidor (phonelib).
- Preço exibido vem exclusivamente de `@product.price_cents`; o navegador nunca envia valor.

## SEO / social

```erb
<title><%= @product.meta_title.presence || @product.name %></title>
<meta name="description" content="<%= @product.meta_description %>">
<meta property="og:title" ...> <meta property="og:image" content="<%= url_for(@product.og_image.variant(:og)) %>">
<meta name="robots" content="index,follow">   <!-- "noindex" no preview -->
<link rel="canonical" href="https://devbatista.online/<%= @product.slug %>">
```

`og_image` variant 1200×630 WebP/JPEG.

## Performance

- Imagens: variants WebP, `loading="lazy"` (exceto mockup do hero), `width`/`height` explícitos.
- CSS: Tailwind purgado; sem fontes externas (system font stack) ou no máximo 1 família via `font-display: swap`.
- JS: entry `landing.js` (importmap) que ativa só os módulos presentes na página via `data-module`
  (`attribution`, `checkout`, `tracking`, `sticky_cta`). Sem Turbo/Stimulus; sem libs. PayPal SDK sob demanda.
  Orçamento: JS próprio da LP ≤ 10 KB (sem contar SDKs de terceiros).
- Cache: `fresh_when(@product)` (ETag/Last-Modified) + `Cache-Control: public, max-age=60` via Cloudflare;
  tracking e checkout não dependem de sessão para cachear a página. UTMs são capturadas em cookie por
  `modules/attribution.js` no cliente **e** lidas no `POST /checkout/paypal` (ver spec 10), então cache da página
  não perde atribuição. O token CSRF é lido de `<meta name="csrf-token">` — como a página pode ser cacheada,
  o endpoint de checkout DEVE aceitar requisições sem sessão prévia (`protect_from_forgery` com
  `null_session` nos controllers de checkout) e confiar em rate limit + validação server-side, não no CSRF.
- Meta: Lighthouse mobile ≥ 85 performance; LCP < 2.5 s.

## Acessibilidade mínima

Contraste AA, botão de compra com texto claro, `alt` em imagens, foco visível, FAQ navegável por teclado.

## Estados

| Status do produto | `/:slug` público | Preview admin |
|---|---|---|
| draft | 404 | 200 com banner |
| published | 200 | 200 com banner |
| archived | 404 | 200 com banner |

## Critérios de aceite

- [ ] `/21-day-procrastination-reset` renderiza todos os blocos com dados do admin; blocos opcionais somem quando vazios.
- [ ] Layout OK em 375 px (iPhone SE) e 1280 px; nenhum overflow horizontal.
- [ ] Botão PayPal aparece em mobile Safari e Chrome Android.
- [ ] Lighthouse mobile: Performance ≥ 85, Accessibility ≥ 90.
- [ ] `/qualquer-slug-inexistente` → 404 com página amigável.
- [ ] Slug reservado (`admin`) não pode ser salvo como slug de produto.
- [ ] `og:image` e `description` corretos ao colar a URL no Facebook Debugger.
