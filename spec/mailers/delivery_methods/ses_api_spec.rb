require "rails_helper"

RSpec.describe DeliveryMethods::SesApi do
  it "está registrado como :ses_api no Action Mailer" do
    expect(ActionMailer::Base.delivery_methods[:ses_api]).to eq(described_class)
  end

  it "entrega pelo Providers::Ses::Client e grava o Message-ID do SES no email" do
    order = create(:order, :paid)
    create(:download_token, order:)
    sdk = stubbed_ses_sdk(send_email: { message_id: "0100018-xyz" })
    client = Providers::Ses::Client.new(sdk:, access_key_id: "k", secret_access_key: "s")

    mail = OrderMailer.with(order:).delivery
    mail.delivery_method(described_class, client:)
    mail.deliver_now

    expect(mail.message_id).to eq("0100018-xyz@email.amazonses.com")
    expect(sdk.api_requests.last[:params][:destination][:to_addresses]).to eq([ order.client.email ])
  end
end
