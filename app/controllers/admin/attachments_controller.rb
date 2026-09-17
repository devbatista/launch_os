module Admin
  # Remove um arquivo do produto (spec 05, seção 4: previews podem ser removidos individualmente;
  # os demais também). Sem JS: é um form DELETE comum que volta para o formulário do produto.
  class AttachmentsController < BaseController
    before_action :set_product

    def destroy
      attachment = ActiveStorage::Attachment.find_by!(id: params[:id], record: @product, name: Product::ATTACHMENT_NAMES)

      if @product.published? && @product.required_for_publish?(attachment)
        redirect_to edit_admin_product_path(@product, anchor: "files"), status: :see_other,
                    alert: "Este arquivo é obrigatório em um produto publicado. Despublique antes de removê-lo."
      else
        attachment.purge_later
        redirect_to edit_admin_product_path(@product, anchor: "files"), status: :see_other, notice: "Arquivo removido."
      end
    end

    private
      def set_product
        @product = Product.find_by!(slug: params[:product_id])
      end
  end
end
