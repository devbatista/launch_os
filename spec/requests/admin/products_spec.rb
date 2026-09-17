require "rails_helper"

RSpec.describe "Admin products" do
  let(:valid_params) do
    { product: { name: "Focus Reset", slug: "focus-reset", headline: "Get it done", subheadline: "In 21 days",
                 price: "14.90", compare_at_price: "29", currency: "USD", cta_text: "Buy Now",
                 description: "<p>What's inside</p>", problem_text: "You stall.", guarantee_text: "14 days.",
                 refund_days: 14, meta_title: "Focus Reset", meta_description: "A reset." } }
  end

  it "exige sessão em todas as rotas" do
    product = create(:product)

    get admin_products_path
    expect(response).to redirect_to(admin_login_path)
    get edit_admin_product_path(product)
    expect(response).to redirect_to(admin_login_path)
    patch publish_admin_product_path(product)
    expect(response).to redirect_to(admin_login_path)
    get preview_admin_product_path(product)
    expect(response).to redirect_to(admin_login_path)
  end

  context "quando autenticado" do
    before { sign_in_admin }

    describe "GET /admin/products" do
      it "lista os produtos com status e preço" do
        create(:product, name: "Alpha", price_cents: 1490)
        create(:product, :published, name: "Beta")

        get admin_products_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alpha", "Beta", "$14.90", "Rascunho", "Publicado")
      end
    end

    describe "POST /admin/products" do
      it "cria um rascunho com todos os campos e converte o preço para centavos" do
        expect { post admin_products_path, params: valid_params }.to change(Product, :count).by(1)

        product = Product.find_by!(slug: "focus-reset")
        expect(response).to redirect_to(edit_admin_product_path(product))
        expect(product).to be_draft
        expect(product).to have_attributes(price_cents: 1490, compare_at_price_cents: 2900, refund_days: 14, cta_text: "Buy Now")
        expect(product.description.to_plain_text).to eq("What's inside")
      end

      it "gera o slug a partir do nome quando vazio" do
        post admin_products_path, params: valid_params.deep_merge(product: { slug: "" })

        expect(Product.sole.slug).to eq("focus-reset")
      end

      it "reexibe o formulário com erros (422)" do
        post admin_products_path, params: valid_params.deep_merge(product: { slug: "admin", price: "0" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("reservado", "Preço")
        expect(Product.count).to eq(0)
      end
    end

    describe "GET /admin/products/:slug" do
      it "mostra status, URL pública e o que falta para publicar" do
        product = create(:product, slug: "reset")

        get admin_product_path(product)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("/reset", "Rascunho", "PDF do produto")
      end
    end

    describe "PATCH /admin/products/:slug" do
      it "atualiza e avisa quando o slug de um publicado muda" do
        product = create(:product, :published, slug: "old-slug")

        patch admin_product_path(product), params: { product: { slug: "new-slug" } }

        expect(product.reload.slug).to eq("new-slug")
        expect(response).to redirect_to(edit_admin_product_path(product))
        expect(flash[:notice]).to include("slug mudou")
      end

      it "reexibe o formulário com erros (422)" do
        product = create(:product)

        patch admin_product_path(product), params: { product: { headline: "" } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "publicação" do
      it "não publica sem PDF e mantém draft" do
        product = create(:product, :with_images)
        create(:benefit, product:)

        patch publish_admin_product_path(product)

        expect(response).to redirect_to(admin_product_path(product))
        expect(flash[:alert]).to include("PDF do produto")
        expect(product.reload).to be_draft
      end

      it "publica, preenche published_at, despublica e arquiva" do
        product = create(:product, :with_pdf, :with_images)
        create(:benefit, product:)

        patch publish_admin_product_path(product)
        expect(product.reload).to be_published
        expect(product.published_at).to be_present

        patch unpublish_admin_product_path(product)
        expect(product.reload).to be_draft

        patch archive_admin_product_path(product)
        expect(product.reload).to be_archived
      end
    end

    describe "DELETE /admin/products/:slug" do
      it "exclui rascunho" do
        product = create(:product)

        expect { delete admin_product_path(product) }.to change(Product, :count).by(-1)
        expect(response).to redirect_to(admin_products_path)
      end

      it "não exclui produto publicado" do
        product = create(:product, :published)

        expect { delete admin_product_path(product) }.not_to change(Product, :count)
        expect(response).to redirect_to(admin_product_path(product))
        expect(flash[:alert]).to include("Arquive")
      end
    end

    describe "GET /admin/products/:slug/preview" do
      it "renderiza a LP de um rascunho com banner, noindex e compra desabilitada" do
        product = create(:product, :with_lp_content, slug: "draft-preview")

        get preview_admin_product_path(product)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("DRAFT PREVIEW", "Status: draft", "Purchases are disabled in preview",
                                         '<meta name="robots" content="noindex,nofollow">', "Sound familiar?")
        expect(response.body).not_to include('data-module="checkout"')
        expect(response.headers["Cache-Control"]).not_to include("public")
      end

      it "funciona para archived e published, em inglês" do
        create(:product, :archived, slug: "arch")
        create(:product, :published, slug: "pub")

        get preview_admin_product_path("arch")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Status: archived")

        get preview_admin_product_path("pub")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Status: published", "What you'll get", "$14.90")
      end

      it "mostra os links Preview e Ver ao vivo na tela do produto" do
        draft = create(:product, slug: "d")
        published = create(:product, :published, slug: "p")

        get admin_product_path(draft)
        expect(response.body).to include(preview_admin_product_path(draft))
        expect(response.body).not_to include(%(href="#{draft.public_url}"))

        get admin_product_path(published)
        expect(response.body).to include(preview_admin_product_path(published), "Ver ao vivo", %(href="#{published.public_url}"))
      end
    end

    it "responde 404 para slug inexistente" do
      get admin_product_path("nope")

      expect(response).to have_http_status(:not_found)
    end
  end
end
