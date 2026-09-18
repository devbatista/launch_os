module Orders
  # pending|disputed → paid. Cria/atualiza o Client com o pagador do PayPal e grava o opt-in de WhatsApp
  # (texto e data) como evidência. Idempotente: se já está paid, devolve o pedido sem efeitos.
  # O download token (2.4) e o DeliverOrderJob (2.6) são enfileirados aqui quando existirem.
  class MarkPaid
    def self.call(order, capture:, payer:, source:) = new.call(order, capture:, payer:, source:)

    def call(order, capture:, payer:, source:)
      order.with_lock do
        return order if order.paid?
        raise InvalidTransition, "#{order.status} → paid (#{source})" unless order.pending? || order.disputed?

        # Sem pagador (ex.: disputa resolvida a favor) mantém o Client e o capture id já gravados.
        client = upsert_client(order, payer || {}) || order.client
        order.update!(status: :paid, paid_at: order.paid_at || Time.current, client:,
                      paypal_capture_id: capture&.dig("id").presence || order.paypal_capture_id,
                      payer_email: client&.email || order.payer_email, payer_name: client&.name || order.payer_name)
        Rails.logger.info { "[orders] #{order.id} paid via #{source}" }
      end
      order
    end

    private
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
