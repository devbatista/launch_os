module Admin
  # Clientes (spec 11): lista com busca e filtro de opt-in, detalhe com pedidos e mensagens, e a
  # revogação do opt-in de WhatsApp (pedido ao suporte). Telefone sempre mascarado na tela.
  class ClientsController < BaseController
    include Paginated

    PAID_ORDERS_COUNT = "(SELECT COUNT(*) FROM orders WHERE orders.client_id = clients.id AND orders.status = 'paid')".freeze

    def index
      scope = Client.select("clients.*, #{PAID_ORDERS_COUNT} AS paid_orders_count").order(last_purchase_at: :desc, created_at: :desc)
      scope = scope.where(whatsapp_opt_in: true) if params[:opt_in] == "1"
      if params[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip.downcase)}%"
        scope = scope.where("clients.email ILIKE :like OR LOWER(clients.name) LIKE :like", like:)
      end

      @clients, @page = paginate(scope)
    end

    def show
      @client = Client.find(params[:id])
      @orders = @client.orders.includes(:product, :download_token).recent
      @message_logs = @client.message_logs.includes(:order).recent
    end

    def revoke_whatsapp_opt_in
      client = Client.find(params[:id])
      client.opt_out_whatsapp!
      redirect_to admin_client_path(client), status: :see_other, notice: "Opt-in de WhatsApp revogado: nenhuma mensagem será enviada a este cliente."
    end
  end
end
