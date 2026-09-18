require "rails_helper"

# /access/recover (spec 08, T19 e T26): resposta idêntica exista ou não a compra; reenvio por
# Delivery::ResendAccess; honeypot, tempo mínimo e rate limit por IP e por email.
RSpec.describe "Access recovery" do
  let(:notice) { "If we find a purchase with that email" }

  # Token do form gerado há `age` segundos (o controller exige >= 2 s entre render e envio).
  def form_token(age: 5) = Rails.application.message_verifier(:access_recovery).generate(age.seconds.ago.to_i, expires_in: 1.day)

  def recover(email, token: form_token, **extra)
    post access_recover_path, params: { email:, form_token: token, **extra }
  end

  it "mostra o formulário com honeypot e token assinado, sem indexação" do
    get access_recover_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lost your download link?", 'name="email"', 'name="website"', 'name="form_token"', 'content="noindex,nofollow"')
  end

  it "email com compra paga: regenera o token expirado e enfileira o reenvio; resposta neutra (T19)" do
    client = create(:client, email: "jane@example.com")
    order = create(:order, :paid, client:)
    token = create(:download_token, :expired, order:)

    expect { recover("  Jane@Example.COM ") }
      .to have_enqueued_job(SendOrderEmailJob).with(order.id, template: "access_resend").once

    expect(response).to redirect_to(access_recover_path)
    follow_redirect!
    expect(response.body).to include(notice)
    expect(token.reload).to be_active
  end

  it "email sem compra: mesma resposta e nenhum email (T19)" do
    expect { recover("nobody@example.com") }.not_to have_enqueued_job(SendOrderEmailJob)

    expect(response).to redirect_to(access_recover_path)
    follow_redirect!
    expect(response.body).to include(notice)
  end

  it "reenvia cada pedido pago do cliente, mas não os reembolsados nem os de token revogado" do
    client = create(:client)
    paid_a = create(:order, :paid, client:)
    paid_b = create(:order, :paid, client:)
    create(:order, :refunded, client:)
    revoked = create(:order, :paid, client:)
    create(:download_token, :revoked, order: revoked)

    expect { recover(client.email) }
      .to have_enqueued_job(SendOrderEmailJob).with(paid_a.id, template: "access_resend")
      .and have_enqueued_job(SendOrderEmailJob).with(paid_b.id, template: "access_resend")
    expect(SendOrderEmailJob).not_to have_been_enqueued.with(revoked.id, template: "access_resend")
  end

  it "honeypot preenchido, envio rápido demais ou token ausente/forjado: resposta neutra sem reenviar" do
    # Um cliente por caso: o limite por email é 3/h.
    emails = Array.new(4) { create(:download_token).order.client.email }

    expect { recover(emails[0], website: "http://spam.example") }.not_to have_enqueued_job(SendOrderEmailJob)
    expect(response).to redirect_to(access_recover_path)

    expect { recover(emails[1], token: form_token(age: 0)) }.not_to have_enqueued_job(SendOrderEmailJob)
    expect { recover(emails[2], token: "") }.not_to have_enqueued_job(SendOrderEmailJob)
    expect { recover(emails[3], token: "forged--abc") }.not_to have_enqueued_job(SendOrderEmailJob)
    expect(response).to redirect_to(access_recover_path)
  end

  it "email inválido volta ao formulário com erro (422) sem consultar nada" do
    recover("not-an-email")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Please enter a valid email address.")
  end

  it "rate limit: 6ª tentativa em 10 min pelo mesmo IP → 429 (T26)" do
    5.times { |i| recover("user#{i}@example.com") }
    expect(response).to redirect_to(access_recover_path)

    recover("user6@example.com")
    expect(response).to have_http_status(:too_many_requests)

    travel 11.minutes
    recover("user7@example.com")
    expect(response).to redirect_to(access_recover_path)
  end

  it "rate limit: 4ª tentativa em 1 h para o mesmo email → 429, mesmo variando caixa/espaços" do
    recover("jane@example.com")
    recover("JANE@example.com")
    recover(" jane@example.com ")
    expect(response).to redirect_to(access_recover_path)

    recover("jane@example.com")
    expect(response).to have_http_status(:too_many_requests)

    # Outro email no mesmo IP ainda passa (o limite por IP é 5).
    recover("other@example.com")
    expect(response).to redirect_to(access_recover_path)
  end
end
