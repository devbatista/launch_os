module Admin
  # CRUD do catálogo (docs/specs/05-catalogo-produtos-admin.md). Uploads de arquivos entram na 1.5;
  # preview da LP na 1.7.
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
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      slug_before = @product.slug

      if @product.update(product_params)
        notice = "Produto atualizado."
        notice += " Atenção: o slug mudou e links já divulgados (anúncios) deixam de funcionar." if @product.published? && slug_before != @product.slug
        redirect_to edit_admin_product_path(@product), notice:
      else
        render :edit, status: :unprocessable_entity
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

      def product_params
        params.expect(product: [
          :name, :slug, :headline, :subheadline, :cta_text, :price, :compare_at_price, :currency,
          :description, :problem_text, :guarantee_text, :refund_days, :meta_title, :meta_description
        ])
      end
  end
end
