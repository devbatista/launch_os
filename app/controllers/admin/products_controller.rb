module Admin
  # CRUD do catálogo (docs/specs/05-catalogo-produtos-admin.md), incluindo os arquivos (PDF e imagens).
  # Preview da LP na 1.7.
  class ProductsController < BaseController
    before_action :set_product, only: %i[show edit update destroy publish unpublish archive]

    def index
      @products = Product.recent
    end

    def show
    end

    def new
      @product = Product.new
    end

    def create
      @product = Product.new(product_params)

      if @product.save
        redirect_to edit_admin_product_path(@product), notice: "Produto criado. Complete o conteúdo e os arquivos antes de publicar."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      slug_before = @product.slug

      attrs = product_params
      # `preview_images=` substitui a coleção inteira (Rails ≥ 7.1); no update queremos acrescentar às existentes.
      # Atribuímos `blobs + novos` (em vez de `attach`, que salvaria na hora) para validar tudo num único save.
      new_previews = Array(attrs.delete(:preview_images))
      @product.assign_attributes(attrs)
      @product.preview_images = @product.preview_images.blobs + new_previews if new_previews.any?

      if @product.save
        notice = "Produto atualizado."
        notice += " Atenção: o slug mudou e links já divulgados (anúncios) deixam de funcionar." if @product.published? && slug_before != @product.slug
        redirect_to edit_admin_product_path(@product), notice:
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @product.deletable?
        @product.destroy!
        redirect_to admin_products_path, notice: "Produto excluído.", status: :see_other
      else
        redirect_to admin_product_path(@product), alert: "Só é possível excluir rascunhos sem pedidos. Arquive o produto.", status: :see_other
      end
    end

    def publish
      if @product.publish
        redirect_to admin_product_path(@product), notice: "Produto publicado."
      else
        redirect_to admin_product_path(@product), alert: "Não foi possível publicar: falta #{@product.missing_for_publish.join(', ')}."
      end
    end

    def unpublish
      @product.unpublish
      redirect_to admin_product_path(@product), notice: "Produto despublicado (rascunho)."
    end

    def archive
      @product.archive
      redirect_to admin_product_path(@product), notice: "Produto arquivado. A landing page passa a responder 404."
    end

    private
      def set_product
        @product = Product.find_by!(slug: params[:id])
      end

      # Campos de arquivo vazios são descartados: para o Active Storage, atribuir "" significa apagar o anexo.
      def product_params
        permitted = params.expect(product: [
          :name, :slug, :headline, :subheadline, :cta_text, :price, :compare_at_price, :currency,
          :description, :problem_text, :guarantee_text, :refund_days, :meta_title, :meta_description,
          :pdf_file, :cover_image, :mockup_image, :og_image, preview_images: []
        ])
        permitted[:preview_images] = Array(permitted[:preview_images]).compact_blank if permitted.key?(:preview_images)
        permitted.reject { |key, value| Product::ATTACHMENT_NAMES.include?(key) && value.blank? }
      end
  end
end
