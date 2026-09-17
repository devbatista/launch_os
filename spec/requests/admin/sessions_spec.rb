require "rails_helper"

# T13 (lockout) e T26 (rate limit) — docs/specs/15-plano-de-testes.md; critérios da spec 04.
RSpec.describe "Admin sessions" do
  let(:password) { "correct-horse-battery" }
  let!(:user) { create(:user, email_address: "admin@example.com", password:) }

  def sign_in(email: "admin@example.com", pass: password)
    post admin_login_path, params: { email_address: email, password: pass }
  end

  describe "GET /admin/login" do
    it "renderiza o formulário" do
      get admin_login_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Entrar")
    end

    it "redireciona para o dashboard quando já autenticado" do
      sign_in
      get admin_login_path

      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  describe "POST /admin/login" do
    it "cria a Session, registra o acesso e redireciona para o dashboard" do
      expect { sign_in }.to change(Session, :count).by(1)

      expect(response).to redirect_to(admin_dashboard_path)
      expect(cookies[:session_id]).to be_present
      expect(user.reload.last_sign_in_at).to be_within(2.seconds).of(Time.current)
      expect(Session.sole).to have_attributes(user:, ip_address: "127.0.0.1")
    end

    it "volta para a página pedida antes do login" do
      get admin_dashboard_path
      sign_in

      expect(response).to redirect_to(admin_dashboard_url)
    end

    it "aceita o email com espaços e maiúsculas" do
      sign_in(email: "  ADMIN@example.com ")

      expect(response).to redirect_to(admin_dashboard_path)
    end

    it "rejeita senha errada com mensagem genérica e conta a falha" do
      sign_in(pass: "wrong-password-123")

      expect(response).to redirect_to(admin_login_path)
      expect(flash[:alert]).to eq(Admin::SessionsController::INVALID_CREDENTIALS)
      expect(user.reload.failed_attempts).to eq(1)
      expect(Session.count).to eq(0)
    end

    it "usa a mesma mensagem para email inexistente" do
      sign_in(email: "nobody@example.com")

      expect(response).to redirect_to(admin_login_path)
      expect(flash[:alert]).to eq(Admin::SessionsController::INVALID_CREDENTIALS)
    end

    context "com lockout (T13)" do
      it "bloqueia após 5 senhas erradas e recusa a senha correta durante 15 min" do
        5.times { sign_in(pass: "wrong-password-123") }
        expect(user.reload).to be_locked

        sign_in
        expect(response).to redirect_to(admin_login_path)
        expect(flash[:alert]).to eq(Admin::SessionsController::LOCKED)
        expect(Session.count).to eq(0)

        travel_to(16.minutes.from_now) do
          sign_in
          expect(response).to redirect_to(admin_dashboard_path)
          expect(user.reload).to have_attributes(failed_attempts: 0, locked_at: nil)
        end
      end
    end

    context "com rate limit (T26)" do
      it "responde 429 na 11ª tentativa em 3 minutos" do
        10.times { sign_in(pass: "wrong-password-123") }
        expect(response).to have_http_status(:redirect)

        sign_in
        expect(response).to have_http_status(:too_many_requests)

        travel_to(4.minutes.from_now) do
          sign_in(pass: "wrong-password-123")
          expect(response).to have_http_status(:redirect)
        end
      end
    end
  end

  describe "DELETE /admin/logout" do
    it "destrói a Session e o cookie deixa de valer" do
      sign_in
      session_id = Session.sole.id

      delete admin_logout_path

      expect(response).to redirect_to(admin_login_path)
      expect(Session.exists?(session_id)).to be(false)

      get admin_dashboard_path
      expect(response).to redirect_to(admin_login_path)
    end
  end
end
