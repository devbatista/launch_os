module Admin
  # Base das coleções da LP (benefits, testimonials, faqs) — contrato da spec 05:
  #   fetch (X-Requested-With) → 200 com o partial da lista inteira; 422 com o partial + erros
  #   sem JS               → redirect para o formulário do produto (funcionalidade preservada)
  class CollectionItemsController < BaseController
    before_action :set_product
    before_action :set_item, only: %i[update destroy move]

    def create
      @item = collection.build(item_params)

      if @item.save
        respond_ok
      else
        respond_invalid
      end
    end

    def update
      if @item.update(item_params)
        respond_ok
      else
        respond_invalid
      end
    end

    def destroy
      @item.destroy!
      respond_ok
    end

    def move
      @item.move(params[:direction])
      respond_ok
    rescue ArgumentError
      head :bad_request
    end

    private
      # Subclasses definem :benefits, :testimonials ou :faqs e os campos permitidos.
      def collection_name = raise(NotImplementedError)
      def permitted_attributes = raise(NotImplementedError)

      def set_product
        @product = Product.find_by!(slug: params[:product_id])
      end

      def collection
        @product.public_send(collection_name)
      end

      def set_item
        @item = collection.find(params[:id])
      end

      def item_params
        params.expect(collection_name.to_s.singularize.to_sym => permitted_attributes)
      end

      def respond_ok
        if request.xhr?
          render_list(status: :ok)
        else
          redirect_to edit_admin_product_path(@product, anchor: collection_name), status: :see_other
        end
      end

      def respond_invalid
        if request.xhr?
          render_list(status: :unprocessable_entity, invalid_item: @item)
        else
          redirect_to edit_admin_product_path(@product, anchor: collection_name),
                      alert: "#{collection_label}: #{@item.errors.full_messages.to_sentence}", status: :see_other
        end
      end

      def render_list(status:, invalid_item: nil)
        render partial: "admin/#{collection_name}/list", layout: false, status:,
               locals: { product: @product, items: collection.reload, invalid_item: }
      end

      def collection_label
        { benefits: "Benefício", testimonials: "Depoimento", faqs: "FAQ" }.fetch(collection_name)
      end
  end
end
