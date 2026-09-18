require "rails_helper"

# LP pública (spec 06 / T14): só `published` responde, blocos opcionais somem, meta tags e cache.
RSpec.describe "Landing pages" do
  describe "GET /:slug" do
    it "renderiza todos os blocos de um produto completo" do
      product = create(:product, :published, :with_lp_content, slug: "reset", compare_at_price_cents: 2900)
      product.preview_images.attach(image_upload)

      get "/reset"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.headline, product.subheadline, "$14.90", "$29.00")
      expect(response.body).to include("Sound familiar?", "What you'll get", "What's inside", "Take a peek inside",
                                       "What readers say", 'id="buy"', "money-back guarantee", "Frequently asked questions")
      expect(response.body).to include(product.benefits.first.title, product.testimonials.first.author_name, product.faqs.first.question)
      expect(response.body).to include("Privacy", "Terms", "Refund Policy", ENV.fetch("SUPPORT_EMAIL", "support@devbatista.online"))
    end

    it "esconde os blocos opcionais quando vazios" do
      create(:product, :published, slug: "bare", problem_text: nil, guarantee_text: nil, subheadline: nil)

      get "/bare"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Sound familiar?", "What's inside", "Take a peek inside", "What readers say", "Frequently asked questions")
      expect(response.body).to include("What you'll get", 'id="buy"')
    end

    it "usa imagens pelo proxy do Active Storage com variant WebP, lazy exceto o hero" do
      product = create(:product, :published, slug: "img")
      product.preview_images.attach(image_upload)

      get "/img"

      expect(response.body).to include("/rails/active_storage/representations/proxy/")
      expect(response.body).not_to include("/representations/redirect/")
      expect(response.body).to match(/<img[^>]*loading="eager"[^>]*>/)
      expect(response.body).to match(/<img[^>]*loading="lazy"[^>]*>/)
    end

    it "responde 404 para draft, archived e slug inexistente" do
      create(:product, slug: "draft-one")
      create(:product, :archived, slug: "archived-one")

      get "/draft-one"
      expect(response).to have_http_status(:not_found)
      get "/archived-one"
      expect(response).to have_http_status(:not_found)
      get "/nope"
      expect(response).to have_http_status(:not_found)
    end

    it "não captura rotas fixas" do
      get "/up"
      expect(response).to have_http_status(:ok)
      get "/admin"
      expect(response).to redirect_to("/admin/dashboard")
    end

    it "é cacheável: ETag/Last-Modified, public max-age=60 e 304 quando não mudou" do
      create(:product, :published, slug: "cached")

      get "/cached"
      expect(response.headers["Cache-Control"]).to include("public", "max-age=60")
      expect(response.headers["ETag"]).to be_present

      get "/cached", headers: { "If-None-Match" => response.headers["ETag"] }
      expect(response).to have_http_status(:not_modified)
    end

    it "invalida o ETag quando um item da coleção muda (touch)" do
      product = create(:product, :published, slug: "touched")
      get "/touched"
      etag = response.headers["ETag"]

      travel_to(1.minute.from_now) { product.benefits.first.update!(title: "Changed") }

      get "/touched", headers: { "If-None-Match" => etag }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Changed")
    end
  end

  describe "SEO / social" do
    it "emite title, description, canonical, robots e og:*" do
      product = create(:product, :published, slug: "seo", meta_title: "Reset — Focus", meta_description: "Meta desc")
      product.og_image.attach(image_upload)

      get "/seo"

      expect(response.body).to include("<title>Reset — Focus</title>")
      expect(response.body).to include('<meta name="description" content="Meta desc">')
      expect(response.body).to include('<meta name="robots" content="index,follow">')
      expect(response.body).to include(%(<link rel="canonical" href="#{product.public_url}">))
      expect(response.body).to include('<meta property="og:title" content="Reset — Focus">')
      expect(response.body).to match(%r{<meta property="og:image" content="http://www\.example\.com/rails/active_storage/representations/proxy/[^"]+">})
      expect(response.body).to include('<meta property="og:image:width" content="1200">')
    end

    it "cai para a imagem do hero como og:image quando não há og_image" do
      create(:product, :published, slug: "no-og")

      get "/no-og"

      expect(response.body).to include('property="og:image"')
      expect(response.body).not_to include("og:image:width")
    end
  end

  describe "bloco de oferta (#buy)" do
    it "expõe os data-* do checkout e não mostra telefone/opt-in sem Twilio" do
      product = create(:product, :published, slug: "offer")

      get "/offer"

      expect(response.body).to include('data-module="checkout"', %(data-product-id="#{product.id}"),
                                       'data-create-url="/checkout/paypal"', 'data-capture-url="/checkout/paypal/capture"',
                                       'data-whatsapp-enabled="false"', 'id="paypal-button-container"')
      expect(response.body).not_to include('name="phone"', "whatsapp_opt_in")
    end

    it "mostra telefone e opt-in desmarcado com TWILIO_ENABLED=true" do
      stub_const("ENV", ENV.to_h.merge("TWILIO_ENABLED" => "true"))
      create(:product, :published, slug: "offer-wa")

      get "/offer-wa"

      expect(response.body).to include(%(data-whatsapp-enabled="true"), %(name="phone"), I18n.t("checkout.whatsapp_opt_in"))
      expect(response.body).to match(/<input type="checkbox" name="whatsapp_opt_in" value="1"[^>]*>/)
      expect(response.body).not_to match(/name="whatsapp_opt_in"[^>]*checked/)
    end
  end
end
