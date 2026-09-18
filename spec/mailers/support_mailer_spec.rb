require "rails_helper"

RSpec.describe SupportMailer do
  before { stub_const("ENV", ENV.to_h.merge("SUPPORT_EMAIL" => "support@devbatista.online", "APP_HOST" => "www.example.com", "APP_PROTOCOL" => "http")) }

  it "encaminha a mensagem do WhatsApp ao suporte com cliente, texto e link do painel" do
    client = create(:client, :with_whatsapp_opt_in, name: "Jane Buyer", email: "jane@example.com")

    mail = described_class.with(phone: "+14155552671", body: "The link doesn't open", client:, opted_out: false).inbound_whatsapp

    expect(mail.to).to eq([ "support@devbatista.online" ])
    expect(mail.subject).to eq("[WhatsApp] Mensagem de Jane Buyer")
    expect(mail.html_part.decoded).to include("+14155552671", "jane@example.com", "The link doesn&#39;t open", "/admin/clients/#{client.id}")
    expect(mail.text_part.decoded).to include("The link doesn't open")
  end

  it "STOP de número desconhecido: assunto com telefone mascarado e aviso de opt-out" do
    mail = described_class.with(phone: "+14155552671", body: "STOP", client: nil, opted_out: true).inbound_whatsapp
    expect(mail.subject).to eq("[WhatsApp] STOP recebido de +1 ••• ••• 2671")
    expect(mail.html_part.decoded).to include("não cadastrado", "Opt-out registrado")
  end
end
