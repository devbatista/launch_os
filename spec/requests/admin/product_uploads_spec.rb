require "rails_helper"

# Arquivos do produto pelo admin (spec 05, seção 4 / tarefa 1.5).
RSpec.describe "Admin product uploads" do
  let(:base_params) { { name: "Focus Reset", headline: "Get it done", price: "14.90" } }

  before { sign_in_admin }

  describe "POST /admin/products" do
    it "cria o produto com PDF, imagens e previews" do
      post admin_products_path, params: { product: base_params.merge(
        pdf_file: pdf_upload, cover_image: image_upload, mockup_image: image_upload, og_image: image_upload,
        favicon: image_upload, preview_images: [ image_upload, image_upload ]
      ) }

      product = Product.sole
      expect(response).to redirect_to(edit_admin_product_path(product))
      expect(product.pdf_file).to be_attached
      expect(product.cover_image).to be_attached
      expect(product.mockup_image).to be_attached
      expect(product.og_image).to be_attached
      expect(product.favicon).to be_attached
      expect(product.preview_images.count).to eq(2)
      expect(product.pdf_file.blob.service_name).to eq("test")
    end

    it "rejeita tipo inválido com 422 e não persiste nada" do
      post admin_products_path, params: { product: base_params.merge(pdf_file: text_upload, cover_image: text_upload) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("deve ser um arquivo PDF", "deve ser JPEG, PNG ou WebP")
      expect(Product.count).to eq(0)
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it "rejeita imagem acima do limite de tamanho" do
      stub_const("Product::IMAGE_MAX_BYTES", 10)

      post admin_products_path, params: { product: base_params.merge(cover_image: image_upload) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("deve ter no máximo 5 MB")
      expect(Product.count).to eq(0)
    end
  end

  describe "PATCH /admin/products/:slug" do
    let(:product) { create(:product, :with_pdf, :with_images) }

    it "acrescenta previews às existentes em vez de substituir" do
      product.preview_images.attach(image_upload)

      patch admin_product_path(product), params: { product: { preview_images: [ image_upload ] } }

      expect(response).to redirect_to(edit_admin_product_path(product))
      expect(product.reload.preview_images.count).to eq(2)
    end

    it "mantém os arquivos atuais quando os campos vêm vazios" do
      product.preview_images.attach(image_upload)

      patch admin_product_path(product), params: { product: { name: "Renamed", pdf_file: "", cover_image: "", preview_images: [ "" ] } }

      expect(product.reload.name).to eq("Renamed")
      expect(product.pdf_file).to be_attached
      expect(product.cover_image).to be_attached
      expect(product.preview_images.count).to eq(1)
    end

    it "substitui o PDF ao enviar outro" do
      old_blob = product.pdf_file.blob

      patch admin_product_path(product), params: { product: { pdf_file: pdf_upload } }

      expect(product.reload.pdf_file.blob).not_to eq(old_blob)
    end

    it "não passa do limite de previews" do
      product.preview_images.attach(Array.new(Product::PREVIEW_IMAGES_MAX) { image_upload })

      patch admin_product_path(product), params: { product: { preview_images: [ image_upload ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("aceita no máximo 8 imagens")
      expect(product.reload.preview_images.count).to eq(Product::PREVIEW_IMAGES_MAX)
    end
  end

  describe "GET /admin/products/:slug/edit" do
    it "lista os arquivos atuais com botão de remover e mostra previews pelo proxy" do
      product = create(:product, :with_pdf, :with_images)
      product.preview_images.attach(image_upload)

      get edit_admin_product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("product.pdf", "Remover", "remove-attachment-#{product.pdf_file.attachment.id}")
      expect(response.body).to include(rails_storage_proxy_path(product.preview_images.first))
    end
  end

  describe "DELETE /admin/products/:slug/attachments/:id" do
    let(:product) { create(:product, :with_pdf, :with_images) }

    it "remove um preview individualmente e redireciona para a seção de arquivos" do
      product.preview_images.attach(image_upload, image_upload)
      first, second = product.preview_images.attachments.to_a

      delete admin_product_attachment_path(product, first)

      expect(response).to redirect_to(edit_admin_product_path(product, anchor: "files"))
      expect(product.reload.preview_images.attachments.map(&:id)).to eq([ second.id ])
    end

    it "remove o PDF de um rascunho" do
      delete admin_product_attachment_path(product, product.pdf_file.attachment)

      expect(product.reload.pdf_file).not_to be_attached
    end

    it "não remove um arquivo obrigatório de produto publicado" do
      create(:benefit, product:)
      product.publish

      delete admin_product_attachment_path(product, product.pdf_file.attachment)

      expect(response).to redirect_to(edit_admin_product_path(product, anchor: "files"))
      expect(flash[:alert]).to include("Despublique")
      expect(product.reload.pdf_file).to be_attached
    end

    it "remove o favicon (não é obrigatório para publicar)" do
      create(:benefit, product:)
      product.favicon.attach(image_upload)
      product.publish

      delete admin_product_attachment_path(product, product.favicon.attachment)

      expect(product.reload.favicon).not_to be_attached
      expect(product).to be_published
    end

    it "remove a capa de um publicado quando ainda há mockup" do
      create(:benefit, product:)
      product.publish

      delete admin_product_attachment_path(product, product.cover_image.attachment)

      expect(product.reload.cover_image).not_to be_attached
      expect(product).to be_published
    end

    it "responde 404 para anexo de outro produto" do
      other = create(:product, :with_pdf)

      delete admin_product_attachment_path(product, other.pdf_file.attachment)

      expect(response).to have_http_status(:not_found)
      expect(other.reload.pdf_file).to be_attached
    end
  end
end
