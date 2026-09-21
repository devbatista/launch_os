require "rails_helper"

# T30 (spec 15)
RSpec.describe Providers::Ses::Client do
  let(:mail) do
    Mail.new(from: "DevBatista <no-reply@devbatista.online>", to: "Jane Buyer <jane@example.com>",
             reply_to: "support@devbatista.online", subject: "Hi", body: "Hello")
  end

  it "envia o email raw com from/to/reply-to e configuration set, devolvendo o MessageId" do
    sdk = stubbed_ses_sdk(send_email: { message_id: "0100018-abc" })
    client = described_class.new(sdk:, access_key_id: "k", secret_access_key: "s", configuration_set: "launch-os")

    expect(client.send_raw_email(mail)).to eq("0100018-abc")

    request = sdk.api_requests.last
    expect(request[:operation_name]).to eq(:send_email)
    expect(request[:params]).to include(
      from_email_address: "DevBatista <no-reply@devbatista.online>",
      destination: { to_addresses: [ "jane@example.com" ], cc_addresses: [], bcc_addresses: [] },
      reply_to_addresses: [ "support@devbatista.online" ],
      configuration_set_name: "launch-os"
    )
    expect(request[:params].dig(:content, :raw, :data)).to include("Subject: Hi")
  end

  it "throttling, 5xx e rede viram TransientError; rejeição e identidade não verificada, PermanentError" do
    expect { ses_client(send_email: "TooManyRequestsException").send_raw_email(mail) }.to raise_error(Providers::TransientError, /TooManyRequests/)
    expect { ses_client(send_email: "InternalServiceErrorException").send_raw_email(mail) }.to raise_error(Providers::TransientError)
    expect { ses_client(send_email: Seahorse::Client::NetworkingError.new(Errno::ECONNRESET.new)).send_raw_email(mail) }.to raise_error(Providers::TransientError)
    expect { ses_client(send_email: "MessageRejected").send_raw_email(mail) }.to raise_error(Providers::PermanentError, /MessageRejected/)
    expect { ses_client(send_email: "MailFromDomainNotVerifiedException").send_raw_email(mail) }.to raise_error(Providers::PermanentError)
    expect { ses_client(send_email: "AccountSuspendedException").send_raw_email(mail) }.to raise_error(Providers::PermanentError)
  end

  it "omite o configuration set quando não configurado" do
    sdk = stubbed_ses_sdk
    described_class.new(sdk:, access_key_id: "k", secret_access_key: "s", configuration_set: nil).send_raw_email(mail)
    expect(sdk.api_requests.last[:params][:configuration_set_name]).to be_nil
  end
end
