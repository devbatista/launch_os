module Admin
  # Pedidos (spec 11): lista com filtros e busca, detalhe com atribuição, token, mensagens e eventos,
  # e as ações operacionais — reenviar acesso, regenerar/revogar token, resolver disputa. Nenhuma ação
  # altera valor ou marca como pago: isso só acontece via PayPal (capture/webhook).
  class OrdersController < BaseController
    include Paginated

    before_action :set_order, except: :index

    def index
      scope = Order.includes(:product, :client, :message_logs).recent
      scope = scope.where(status: params[:status]) if Order.statuses.key?(params[:status])
      scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
      scope = scope.where(created_at: period_range) if period_range
      scope = search(scope) if params[:q].present?

      @orders, @page = paginate(scope)
      @products = Product.order(:name)
    end

    def show
      @token = @order.download_token
      @message_logs = @order.message_logs.recent
      @webhook_events = @order.webhook_events.recent
    end

    # Delivery::ResendAccess regenera o token se expirou/limite; recusa se foi revogado.
    def resend
      channel = params[:channel].to_s.inquiry
      return redirect_back_to_order(alert: "Canal inválido.") unless channel.email? || channel.whatsapp?
      return redirect_back_to_order(alert: "WhatsApp indisponível para este cliente (sem opt-in, telefone ou Twilio desligado).") if channel.whatsapp? && !whatsapp_available?

      if Delivery::ResendAccess.call(@order, channels: [ channel.to_sym ])
        redirect_back_to_order(notice: "Reenvio por #{channel.email? ? 'email' : 'WhatsApp'} enfileirado.")
      else
        redirect_back_to_order(alert: "Não foi possível reenviar: o pedido não está pago ou o acesso foi revogado (regenere o token antes).")
      end
    end

    def regenerate_token
      return redirect_back_to_order(alert: "Só pedidos pagos têm token.") unless @order.paid?

      token = @order.download_token || @order.create_download_token!
      token.regenerate!
      redirect_back_to_order(notice: "Novo token gerado (válido até #{helpers.datetime_br(token.expires_at)}). Envie o link com \"Reenviar por email\".")
    end

    def revoke_token
      return redirect_back_to_order(alert: "Este pedido não tem token.") unless @order.download_token

      @order.download_token.revoke!
      redirect_back_to_order(notice: "Acesso revogado: o link de download passa a responder 410.")
    end

    # Decisão manual após tratar a disputa no PayPal: paid (vendedor ganhou) ou refunded (perdeu).
    def resolve_dispute
      return redirect_back_to_order(alert: "Este pedido não está em disputa.") unless @order.disputed?
      return redirect_back_to_order(alert: "Desfecho inválido.") unless %w[paid refunded].include?(params[:outcome])

      Orders::ResolveDispute.call(@order, outcome: params[:outcome], source: :admin)
      redirect_back_to_order(notice: params[:outcome] == "paid" ? "Disputa resolvida a favor: pedido volta a pago e o token foi regenerado." : "Disputa resolvida contra: pedido reembolsado e acesso revogado.")
    rescue Orders::InvalidTransition => e
      redirect_back_to_order(alert: "Transição inválida: #{e.message}")
    end

    private
      def set_order
        @order = Order.includes(:product, :client, :download_token).find(params[:id])
      end

      def redirect_back_to_order(**flash)
        redirect_to admin_order_path(@order), status: :see_other, **flash
      end

      def whatsapp_available? = Delivery.whatsapp_enabled? && @order.client&.whatsapp_deliverable?

      # Email do cliente/pagador ou ids do PayPal; ids exatos, email por prefixo/parte.
      def search(scope)
        q = params[:q].strip
        scope.left_joins(:client).where(
          "orders.paypal_order_id = :exact OR orders.paypal_capture_id = :exact OR clients.email ILIKE :like OR orders.payer_email ILIKE :like",
          exact: q, like: "%#{ActiveRecord::Base.sanitize_sql_like(q.downcase)}%"
        )
      end

      def period_range
        return @period_range if defined?(@period_range)

        from = parse_date(params[:from])
        to = parse_date(params[:to])
        @period_range = (from || to) ? (from&.beginning_of_day..to&.end_of_day) : nil
      end

      def parse_date(value)
        Date.iso8601(value.to_s).in_time_zone("America/Sao_Paulo")
      rescue Date::Error
        nil
      end
  end
end
