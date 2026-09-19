require "rails_helper"

# Admin de pedidos (spec 11): lista com filtros/busca, detalhe com dados sensíveis mascarados e as
# ações operacionais (reenvio, token, disputa). Nada altera valor nem marca como pago.
RSpec.describe "Admin orders" do
  it "exige sessão em todas as rotas" do
    order = create(:order, :paid)

    get admin_orders_path
    expect(response).to redirect_to(admin_login_path)
    get admin_order_path(order)
    expect(response).to redirect_to(admin_login_path)
    post resend_admin_order_path(order, channel: "email")
    expect(response).to redirect_to(admin_login_path)
    post revoke_token_admin_order_path(order)
    expect(response).to redirect_to(admin_login_path)
  end

  context "quando autenticado" do
    before { sign_in_admin }

    describe "index" do
      it "lista pedidos com cliente, status, canais e origem; destaca disputas" do
        client = create(:client, email: "jane@example.com")
        paid = create(:order, :paid, :with_attribution, client:)
        create(:message_log, :sent, order: paid)
        disputed = create(:order, :disputed)

        get admin_orders_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("jane@example.com", "facebook / launch-1", "Pago", "Enviado", "Em disputa")
        expect(response.body).to include(%(<tr class="adm-row-danger">)).and include(disputed.id.first(8))
      end

      it "filtra por status, produto e período, e busca por email ou ids do PayPal" do
        other_product = create(:product, :published, slug: "other")
        paid = create(:order, :paid, client: create(:client, email: "find-me@example.com"), paypal_capture_id: "CAP-XYZ-123")
        pending = create(:order, product: other_product)
        old = create(:order, :paid, created_at: 40.days.ago)

        get admin_orders_path(status: "paid")
        expect(response.body).to include(paid.id.first(8), old.id.first(8))
        expect(response.body).not_to include(pending.id.first(8))

        get admin_orders_path(product_id: other_product.id)
        expect(response.body).to include(pending.id.first(8))
        expect(response.body).not_to include(paid.id.first(8))

        get admin_orders_path(from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601)
        expect(response.body).to include(paid.id.first(8))
        expect(response.body).not_to include(old.id.first(8))

        get admin_orders_path(q: "FIND-ME")
        expect(response.body).to include(paid.id.first(8))
        expect(response.body).not_to include(pending.id.first(8), old.id.first(8))

        get admin_orders_path(q: "CAP-XYZ-123")
        expect(response.body).to include(paid.id.first(8))
        expect(response.body).not_to include(old.id.first(8))

        get admin_orders_path(q: pending.paypal_order_id)
        expect(response.body).to include(pending.id.first(8))
        expect(response.body).not_to include(paid.id.first(8))
      end

      it "pagina de 25 em 25 preservando os filtros" do
        create_list(:order, 26, :paid)

        get admin_orders_path(status: "paid")
        expect(response.body).to include("1–25 de 26", "Página 1 de 2", "Próxima")

        get admin_orders_path(status: "paid", page: 2)
        expect(response.body).to include("26–26 de 26", "Anterior")
        expect(response.body).not_to include("Próxima")
      end
    end

    describe "show" do
      it "mostra pagamento, atribuição, cliente com telefone mascarado, token mascarado, mensagens e webhooks" do
        client = create(:client, :with_whatsapp_opt_in, name: "Jane Buyer", email: "jane@example.com")
        order = create(:order, :paid, :with_attribution, client:, paypal_capture_id: "CAP-1")
        token = create(:download_token, order:, download_count: 2)
        create(:message_log, :failed, order:, template: "order_delivery")
        event = create(:webhook_event, :capture_completed, order:, status: "processed")
        event.update!(order:)

        get admin_order_path(order)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Jane Buyer", "jane@example.com", "CAP-1", "utm_campaign", "launch-1")
        expect(response.body).to include("+1 ••• ••• 2671")
        expect(response.body).not_to include("+14155552671")
        expect(response.body).to include("…#{token.token.last(6)}", "2 / 10")
        expect(response.body).not_to include(token.token)
        expect(response.body).to include("order_delivery", "Falhou", "MessageRejected")
        expect(response.body).to include("PAYMENT.CAPTURE.COMPLETED", admin_webhook_event_path(event))
        expect(response.body).to include("Reenviar por email", "Regenerar token", "Revogar acesso")
        expect(response.body).not_to include("Reenviar por WhatsApp") # TWILIO_ENABLED ausente
      end

      it "pedido pendente e sem cliente não oferece ações de token" do
        order = create(:order, pending_reason: "RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION")

        get admin_order_path(order)

        expect(response.body).to include("Sem cliente vinculado", "RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION", "Nenhum token ainda")
        expect(response.body).not_to include("Reenviar por email", "Regenerar token", "Revogar acesso")
      end
    end

    describe "resend" do
      it "por email enfileira o access_resend (regenerando token expirado) e informa" do
        order = create(:order, :paid)
        token = create(:download_token, :expired, order:)

        expect { post resend_admin_order_path(order, channel: "email") }
          .to have_enqueued_job(SendOrderEmailJob).with(order.id, template: "access_resend")

        expect(response).to redirect_to(admin_order_path(order))
        expect(flash[:notice]).to include("email")
        expect(token.reload).to be_active
      end

      it "recusa token revogado, canal inválido e WhatsApp sem opt-in" do
        order = create(:order, :paid)
        create(:download_token, :revoked, order:)

        expect { post resend_admin_order_path(order, channel: "email") }.not_to have_enqueued_job(SendOrderEmailJob)
        expect(flash[:alert]).to include("revogado")

        post resend_admin_order_path(order, channel: "sms")
        expect(flash[:alert]).to include("Canal inválido")

        post resend_admin_order_path(order, channel: "whatsapp")
        expect(flash[:alert]).to include("WhatsApp indisponível")
      end
    end

    describe "tokens" do
      it "regenerate_token cria/renova o token; revoke_token revoga e o download responde 410" do
        order = create(:order, :paid)

        post regenerate_token_admin_order_path(order)
        expect(response).to redirect_to(admin_order_path(order))
        token = order.reload.download_token
        expect(token).to be_active
        first = token.token

        post regenerate_token_admin_order_path(order)
        expect(token.reload.token).not_to eq(first)

        post revoke_token_admin_order_path(order)
        expect(token.reload.revoked_at).to be_present
        get download_path(token.token)
        expect(response).to have_http_status(:gone)

        post regenerate_token_admin_order_path(create(:order))
        expect(flash[:alert]).to include("Só pedidos pagos")
      end
    end

    describe "resolve_dispute" do
      it "paid volta a pago com token regenerado; refunded reembolsa; outros pedidos são recusados" do
        won = create(:order, :disputed)
        create(:download_token, :revoked, order: won)
        post resolve_dispute_admin_order_path(won, outcome: "paid")
        expect(won.reload).to be_paid
        expect(won.download_token.reload).to be_active

        lost = create(:order, :disputed)
        expect { post resolve_dispute_admin_order_path(lost, outcome: "refunded") }
          .to have_enqueued_job(SendOrderEmailJob).with(lost.id, template: "refund_confirmation")
        expect(lost.reload).to be_refunded

        post resolve_dispute_admin_order_path(create(:order, :disputed), outcome: "cancelled")
        expect(flash[:alert]).to include("Desfecho inválido")

        post resolve_dispute_admin_order_path(create(:order, :paid), outcome: "paid")
        expect(flash[:alert]).to include("não está em disputa")
      end
    end
  end
end
