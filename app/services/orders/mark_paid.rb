module Orders
  # pending|disputed → paid. Cria/atualiza o Client com o pagador do PayPal e grava o opt-in de WhatsApp
  # (texto e data) como evidência; garante um DownloadToken ativo (novo, ou regenerado após disputa).
  # Idempotente: se já está paid, devolve o pedido sem efeitos. O DeliverOrderJob (email/WhatsApp) é
  # enfileirado só depois do commit, para o job nunca ler o pedido ainda pendente.
  class MarkPaid
    def self.call(order, capture:, payer:, source:) = new.call(order, capture:, payer:, source:)

    def call(order, capture:, payer:, source:)
      transitioned = false
      order.with_lock do
        next if order.paid?
        raise InvalidTransition, "#{order.status} → paid (#{source})" unless order.pending? || order.disputed?

        # Sem pagador (ex.: disputa resolvida a favor) mantém o Client e o capture id já gravados.
        client = upsert_client(order, payer || {}) || order.client
        order.update!(status: :paid, paid_at: order.paid_at || Time.current, client:,
                      paypal_capture_id: capture&.dig("id").presence || order.paypal_capture_id,
                      payer_email: client&.email || order.payer_email, payer_name: client&.name || order.payer_name,
                      **financials(order, capture, client))
        ensure_download_token(order)
        Rails.logger.info { "[orders] #{order.id} paid via #{source}" }
        transitioned = true
      end
      DeliverOrderJob.perform_later(order.id) if transitioned
      order
    end

    private
      # Tarifa, líquido e conversão reais da captura (spec 18) + país do pagador na data da venda.
      # Write-once: o que já foi gravado não é sobrescrito por uma reentrega do webhook — é dado fiscal.
      def financials(order, capture, client)
        attrs = Providers::Paypal::Breakdown.call(capture)
        attrs[:payer_country] = client&.country
        attrs.compact.reject { |field, _| order.public_send(field).present? }
      end

      # Token criado no capture PENDING (para a Thank You) ou revogado por disputa volta a valer.
      def ensure_download_token(order)
        token = order.download_token
        return order.create_download_token! unless token

        token.regenerate! unless token.active?
        token
      end

      # Sem email do pagador (não deveria acontecer num capture COMPLETED) o pedido fica paid sem Client.
      def upsert_client(order, payer)
        email = payer["email_address"].to_s.strip.downcase
        return nil if email.blank?

        client = Client.find_or_initialize_by(email:)
        client.name ||= [ payer.dig("name", "given_name"), payer.dig("name", "surname") ].compact_blank.join(" ").presence
        client.country ||= payer.dig("address", "country_code")
        if order.phone.present? && order.whatsapp_opt_in? && !client.whatsapp_opt_in?
          client.assign_attributes(phone: order.phone, whatsapp_opt_in: true, whatsapp_opt_in_at: order.created_at,
                                   whatsapp_opt_in_text: I18n.t("checkout.whatsapp_opt_in", locale: :en))
        end
        client.first_purchase_at ||= Time.current
        client.last_purchase_at = Time.current
        client.save!
        client
      end
  end
end
