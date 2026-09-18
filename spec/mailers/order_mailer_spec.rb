require "rails_helper"

RSpec.describe OrderMailer do
  let(:client) { create(:client, email: "jane@example.com", name: "Jane Buyer") }
  let(:order) { create(:order, :paid, client:) }
  let!(:token) { create(:download_token, order:, expires_at: Time.zone.local(2026, 10, 1, 12)) }

  before { stub_const("ENV", ENV.to_h.merge("MAIL_FROM" => "DevBatista <no-reply@devbatista.online>", "SUPPORT_EMAIL" => "support@devbatista.online")) }

  describe "#delivery" do
    let(:mail) { described_class.with(order:).delivery }

    it "vai do MAIL_FROM com reply-to no suporte, ao comprador com nome, em HTML + texto" do
      expect(mail.subject).to eq("Your download is ready — #{order.product.name}")
      expect(mail.from).to eq([ "no-reply@devbatista.online" ])
      expect(mail[:from].display_names).to eq([ "DevBatista" ])
      expect(mail.reply_to).to eq([ "support@devbatista.online" ])
      expect(mail.to).to eq([ "jane@example.com" ])
      expect(mail[:to].display_names).to eq([ "Jane Buyer" ])
      expect(mail).to be_multipart
      expect(mail.attachments).to be_empty
    end

    it "leva o link /download/:token (nunca a Thank You), validade, limite e recuperação de acesso" do
      html = mail.html_part.decoded
      text = mail.text_part.decoded
      link = "http://example.com/download/#{token.token}"

      expect(html).to include("Your download is ready, Jane!").and include(%(href="#{link}")).and include("October 1, 2026").and include("10 downloads max")
      expect(html).to include("http://example.com/access/recover").and include("support@devbatista.online")
      expect(html).not_to include("/thank-you/")
      expect(text).to include(link).and include("October 1, 2026").and include("http://example.com/access/recover")
    end

    it "sem nome do cliente não coloca vírgula solta e usa payer_email quando não há Client" do
      order.update!(client: nil, payer_email: "payer@example.com")
      expect(mail.to).to eq([ "payer@example.com" ])
      expect(mail.html_part.decoded).to include("Your download is ready!")
    end
  end

  it "#access_resend avisa que o link anterior deixou de valer" do
    mail = described_class.with(order:).access_resend
    expect(mail.subject).to eq("Here's your download link — #{order.product.name}")
    expect(mail.html_part.decoded).to include("/download/#{token.token}").and include("any previous link is no longer valid")
    expect(mail.text_part.decoded).to include("/download/#{token.token}")
  end

  it "#refund_confirmation informa valor e encerramento do acesso, sem link de download" do
    mail = described_class.with(order:).refund_confirmation
    expect(mail.subject).to eq("Your refund for #{order.product.name} has been processed")
    expect(mail.html_part.decoded).to include(ApplicationController.helpers.money(order.amount_cents)).and include("deactivated")
    expect(mail.html_part.decoded).not_to include("/download/")
    expect(mail.text_part.decoded).to include("deactivated")
  end

  it "sem email nenhum levanta ArgumentError" do
    order.update!(client: nil, payer_email: nil)
    expect { described_class.with(order:).delivery.message }.to raise_error(ArgumentError, /no recipient/)
  end
end
