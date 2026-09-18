module Checkout
  # Create/capture do pedido no PayPal (docs/specs/07-checkout-paypal.md, fluxo 1 e 3), chamado por
  # modules/checkout.js via fetch JSON. A LP é cacheável e o token CSRF pode estar velho, e o endpoint
  # não usa sessão: a proteção CSRF é desligada de vez (a segurança é o preço server-side, o rate limit
  # e o próprio PayPal). Não usamos `null_session` porque, sem token válido, ele troca o cookie jar por
  # um vazio e perderíamos a atribuição (lo_attr, _fbp, _fbc).
  class PaypalController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    rate_limit to: 20, within: 1.minute, with: :rate_limited

    ATTRIBUTION_COOKIE = "lo_attr"
    MAX_ATTR_LENGTH = 255

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Product not available." }, status: :not_found
    end
    rescue_from Providers::TransientError do |e|
      Rails.logger.warn { "[checkout] transient: #{e.message}" }
      render json: { error: "PayPal is temporarily unavailable. Please try again." }, status: :service_unavailable
    end
    rescue_from Providers::PermanentError do |e|
      Rails.logger.error { "[checkout] permanent: #{e.message}" }
      Sentry.capture_exception(e) if defined?(Sentry)
      render json: { error: "We couldn't start the payment. Please try again or contact support." }, status: :unprocessable_content
    end

    # POST /checkout/paypal → { paypal_order_id }
    def create
      product = Product.published.find(params[:product_id].to_s)
      phone = normalize_phone(params[:phone])

      order = Order.create!(
        product:, amount_cents: product.price_cents, currency: product.currency, # preço SEMPRE do backend
        phone:, whatsapp_opt_in: phone.present? && ActiveModel::Type::Boolean.new.cast(params[:whatsapp_opt_in]) == true,
        ip_address: request.remote_ip, user_agent: request.user_agent.to_s.truncate(MAX_ATTR_LENGTH),
        **attribution
      )
      response = Providers::Paypal::CreateOrder.call(order)

      render json: { paypal_order_id: response["id"] }, status: :created
    end

    # POST /checkout/paypal/capture → { status, order_id, thank_you_url }
    def capture
      order = Order.find_by!(paypal_order_id: params[:paypal_order_id].to_s)
      return render_paid(order) if order.paid? # idempotente

      result = Providers::Paypal::CaptureOrder.call(order)
      capture = result.dig("purchase_units", 0, "payments", "captures", 0) || {}

      case capture["status"]
      when "COMPLETED"
        Orders::MarkPaid.call(order, capture:, payer: result["payer"], source: :capture)
        render_paid(order)
      when "PENDING"
        # Fica pending até o webhook PAYMENT.CAPTURE.COMPLETED. Motivo típico: conta que recebe em outra
        # moeda com aceite manual (RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION). O token já nasce aqui
        # (inativo até o pedido ser pago) para a Thank You mostrar "processing".
        order.update!(paypal_capture_id: capture["id"].presence, pending_reason: capture.dig("status_details", "reason"))
        order.download_token || order.create_download_token!
        Rails.logger.warn { "[checkout] #{order.id} capture pending: #{order.pending_reason}" }
        render json: { status: "pending", order_id: order.id, thank_you_url: thank_you_url(order) }
      else
        Orders::MarkFailed.call(order, reason: capture["status"] || "no capture")
        render json: { status: "failed", error: "Payment was not completed." }, status: :unprocessable_content
      end
    end

    private
      def render_paid(order)
        render json: { status: "completed", order_id: order.id, thank_you_url: thank_you_url(order) }
      end

      def rate_limited
        render json: { error: "Too many requests. Please wait a moment." }, status: :too_many_requests
      end

      # E.164 via phonelib (padrão US); inválido/vazio → nil (e o opt-in não vale sem telefone).
      def normalize_phone(raw)
        return nil if raw.blank?

        parsed = Phonelib.parse(raw.to_s, "US")
        parsed.valid? ? parsed.e164 : nil
      end

      # Cookie first-party lo_attr (modules/attribution.js) + _fbp/_fbc do Pixel; sem cookie, os params
      # da própria requisição (spec 10). Só as chaves conhecidas, truncadas.
      def attribution
        from_cookie = parse_attribution_cookie
        Order::ATTRIBUTION_FIELDS.index_with { |k| clip(from_cookie[k].presence || params[k]) }
                                 .merge(fbp: clip(cookies["_fbp"]), fbc: clip(cookies["_fbc"]))
                                 .compact.symbolize_keys
      end

      def parse_attribution_cookie
        raw = cookies[ATTRIBUTION_COOKIE]
        return {} if raw.blank?

        data = JSON.parse(raw)
        data.is_a?(Hash) ? data : {}
      rescue JSON::ParserError
        {}
      end

      def clip(value)
        value.is_a?(String) ? value.strip.truncate(MAX_ATTR_LENGTH).presence : nil
      end
  end
end
