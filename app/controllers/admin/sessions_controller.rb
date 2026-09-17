module Admin
  # Login/logout do admin (docs/specs/04-autenticacao-admin.md).
  # A mensagem de erro é sempre a mesma para não revelar se o email existe.
  class SessionsController < BaseController
    INVALID_CREDENTIALS = "E-mail ou senha inválidos."
    LOCKED = "Muitas tentativas. Tente novamente em alguns minutos."

    allow_unauthenticated_access only: %i[new create]
    rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limited

    def new
      redirect_to admin_dashboard_path if authenticated?
    end

    def create
      user = User.find_by(email_address: User.normalize_value_for(:email_address, params[:email_address].to_s))

      if user&.locked?
        user.register_failed_attempt!
        log_failed_attempt(user, reason: "locked")
        redirect_to admin_login_path, alert: LOCKED
      elsif user&.authenticate(params[:password].to_s)
        user.register_successful_sign_in!
        start_new_session_for(user)
        redirect_to after_authentication_url
      else
        user&.register_failed_attempt!
        log_failed_attempt(user, reason: "invalid")
        redirect_to admin_login_path, alert: INVALID_CREDENTIALS
      end
    end

    def destroy
      terminate_session
      redirect_to admin_login_path, status: :see_other, notice: "Sessão encerrada."
    end

    private
      def rate_limited
        head :too_many_requests
      end

      # Sem email/senha no log: só o id do usuário (se existir), o motivo e o IP.
      def log_failed_attempt(user, reason:)
        data = { user_id: user&.id, reason:, ip: request.remote_ip, locked: user&.locked? }
        Rails.logger.warn("[admin.login] failed attempt #{data}")
        Sentry.add_breadcrumb(Sentry::Breadcrumb.new(category: "admin.login", message: "failed attempt", data:, level: "warning"))
      end
  end
end
