# "Lost your download link?" (spec 08): um campo de email; a resposta é a MESMA exista ou não uma compra
# (não enumera clientes). Com compra: Delivery::ResendAccess em cada pedido pago (regenera o token se
# expirou/limite, nunca se revogado). Contra bots: honeypot, tempo mínimo de preenchimento (timestamp
# assinado no form) e rate limit por IP e por hash do email. O email nunca vai para o log.
class AccessRecoveriesController < ApplicationController
  allow_unauthenticated_access
  layout "landing"

  rate_limit to: 5, within: 10.minutes, only: :create, with: :rate_limited
  rate_limit to: 3, within: 1.hour, only: :create, by: -> { email_rate_key }, name: "email", with: :rate_limited

  MIN_FILL_SECONDS = 2
  NOTICE = "If we find a purchase with that email, we'll send the link shortly. Check your spam folder too."

  def new
    @form_token = form_token
  end

  def create
    email = normalized_email
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      @form_token = form_token
      @error = "Please enter a valid email address."
      return render :new, status: :unprocessable_content
    end

    resend_access(email) if human?
    redirect_to access_recover_path, notice: NOTICE
  end

  private
    def normalized_email = params[:email].to_s.strip.downcase

    def resend_access(email)
      client = Client.find_by(email:)
      sent = client ? client.orders.paid.includes(:download_token).map { |o| Delivery::ResendAccess.call(o) }.count(true) : 0
      Rails.logger.info { "[access] recovery ip=#{request.remote_ip} found=#{client.present?} resent=#{sent}" }
    end

    # Bot: preencheu o campo escondido, ou enviou antes de MIN_FILL_SECONDS, ou sem o timestamp assinado.
    def human?
      return false if params[:website].present?

      issued_at = verifier.verified(params[:form_token].to_s)
      return false unless issued_at

      Time.current.to_i - issued_at.to_i >= MIN_FILL_SECONDS
    end

    def form_token = verifier.generate(Time.current.to_i, expires_in: 1.day)
    def verifier = Rails.application.message_verifier(:access_recovery)

    # Rate limit por email sem guardar o email no cache: SHA-256 do valor normalizado.
    def email_rate_key = Digest::SHA256.hexdigest(normalized_email)

    def rate_limited
      render plain: "Too many requests. Please try again later.", status: :too_many_requests
    end
end
