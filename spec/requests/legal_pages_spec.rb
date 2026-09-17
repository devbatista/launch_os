require "rails_helper"

# Páginas legais (spec 14): públicas, cacheáveis, com data de atualização; refund lê o prazo do produto.
RSpec.describe "Legal pages" do
  it "responde 200 nas três rotas com título, data de atualização e rodapé" do
    { privacy_path => "Privacy Policy", terms_path => "Terms of Service", refund_policy_path => "Refund Policy" }.each do |path, title|
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<title>#{title} — DevBatista</title>", "<h1", title, "Last updated:")
      expect(response.body).to include(privacy_path, terms_path, refund_policy_path, ENV.fetch("SUPPORT_EMAIL", "support@devbatista.online"))
      expect(response.headers["Cache-Control"]).to include("public")
    end
  end

  it "não exige sessão nem é capturada pela rota da LP" do
    expect(Product::RESERVED_SLUGS).to include("privacy", "terms", "refund-policy")
    expect(build(:product, slug: "privacy")).not_to be_valid

    get "/privacy"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("DRAFT PREVIEW")
  end

  it "cobre os itens mínimos da privacy policy" do
    get privacy_path

    expect(response.body).to include("PayPal", "Twilio", "Amazon Web Services", "Meta", "Google Analytics", "Cookies",
                                     "CCPA", "LGPD", "IP address", "user agent", "UTM", "delete")
  end

  it "cobre os itens mínimos dos terms" do
    get terms_path

    expect(response.body).to include("digital", "non-transferable", "US dollars", "not</strong> medical", "Limitation of liability",
                                     "Governing law", refund_policy_path)
  end

  describe "refund policy" do
    it "usa 14 dias por padrão" do
      get refund_policy_path

      expect(response.body).to include("<strong>14 days</strong>", "Refund")
    end

    it "usa o prazo do produto quando vem com contexto" do
      product = create(:product, slug: "thirty", refund_days: 30)

      get refund_policy_path(product: product.slug)

      expect(response.body).to include("<strong>30 days</strong>", product.name)
    end

    it "ignora slug inexistente" do
      get refund_policy_path(product: "nope")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<strong>14 days</strong>")
    end
  end

  it "é linkada no rodapé da LP com o produto no contexto da refund policy" do
    product = create(:product, :published, slug: "linked", refund_days: 21)

    get "/linked"

    expect(response.body).to include(refund_policy_path(product: "linked"), privacy_path, terms_path)
  end
end
