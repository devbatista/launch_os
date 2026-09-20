require "rails_helper"

# CSP com nonce e headers de segurança (spec 13, tarefa 4.2).
RSpec.describe "Security headers", type: :request do
  # Métodos, não `let`: são lidos depois de cada requisição.
  def csp = response.headers["Content-Security-Policy"]
  def nonce = response.body[/<meta name="csp-nonce" content="([^"]+)"/, 1]

  describe "landing page" do
    before { create(:product, :published, slug: "secure") }

    it "envia CSP com nonce por requisição nos scripts do importmap e libera só PayPal, Meta e GA" do
      get "/secure"

      expect(csp).to include("default-src 'self'", "object-src 'none'", "frame-ancestors 'none'", "base-uri 'self'", "form-action 'self'")
      expect(csp).to match(/script-src 'self' https:\/\/www\.paypal\.com https:\/\/www\.sandbox\.paypal\.com https:\/\/connect\.facebook\.net https:\/\/www\.googletagmanager\.com 'nonce-[^']+'/)
      expect(csp).to match(/style-src 'self' https:\/\/fonts\.googleapis\.com 'nonce-[^']+'/)
      expect(csp).to include("frame-src https://www.paypal.com https://www.sandbox.paypal.com")
      expect(csp).to include("connect-src 'self' https://*.paypal.com https://www.facebook.com https://*.google-analytics.com")
      expect(csp).to include("img-src 'self' data: #{ENV['S3_ENDPOINT'].presence || 'https://*.amazonaws.com'} https://www.facebook.com")
      expect(csp).not_to include("unsafe-inline", "unsafe-eval")

      expect(nonce).to be_present
      expect(csp).to include("'nonce-#{nonce}'")
      expect(response.body).to include(%(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}">), %(<script type="module" nonce="#{nonce}">))
      expect(response.body.scan(/<script(?![^>]*nonce=)[^>]*>/)).to be_empty # nenhum <script> sem nonce
      expect(response.body).not_to match(/<style|style="/)
    end

    it "gera um nonce diferente a cada requisição" do
      get "/secure"
      first = nonce
      reset!
      get "/secure"
      expect(nonce).to be_present
      expect(nonce).not_to eq(first)
    end

    it "envia Permissions-Policy, nosniff e Referrer-Policy" do
      get "/secure"

      expect(response.headers["Permissions-Policy"]).to include("camera=()", "microphone=()", "geolocation=()", "payment=(self)")
      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
      expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end
  end

  describe "admin" do
    it "usa a mesma CSP (Trix lê o nonce da <meta csp-nonce>) no login e nas páginas autenticadas" do
      get admin_login_path
      expect(csp).to match(/script-src[^;]*'nonce-#{Regexp.escape(nonce)}'/)
      expect(csp).to match(/style-src[^;]*'nonce-#{Regexp.escape(nonce)}'/)
      expect(response.body.scan(/<script(?![^>]*nonce=)[^>]*>/)).to be_empty
      expect(response.body).not_to include('style="')

      sign_in_admin
      get new_admin_product_path
      expect(csp).to include("'nonce-#{nonce}'")
      expect(response.body).to include(%(<meta name="csp-nonce" content="#{nonce}" />))
    end
  end
end
