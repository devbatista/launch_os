module Admin
  # Auditoria dos webhooks recebidos (spec 11): lista por provedor/status e o payload bruto de cada
  # evento. Somente leitura — reprocessamento, se necessário, é pelo console ou pelo provedor.
  class WebhookEventsController < BaseController
    include Paginated

    def index
      scope = WebhookEvent.includes(:order).recent
      scope = scope.where(status: params[:status]) if WebhookEvent.statuses.key?(params[:status])
      scope = scope.where(provider: params[:provider]) if WebhookEvent::PROVIDERS.include?(params[:provider])

      @events, @page = paginate(scope)
    end

    def show
      @event = WebhookEvent.includes(:order).find(params[:id])
    end
  end
end
