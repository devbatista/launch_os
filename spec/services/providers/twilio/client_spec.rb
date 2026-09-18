require "rails_helper"

RSpec.describe Providers::Twilio::Client, :twilio do
  let(:client) { described_class.new }

  it "faz POST form-encoded com Basic Auth e os parâmetros do Content Template; 201 → sid (T29)" do
    stub = stub_twilio_message(sid: "SM123")
      .with(body: { "From" => "whatsapp:+14155238886", "To" => "whatsapp:+14155552671", "ContentSid" => "HX1",
                    "ContentVariables" => { "1" => "Jane", "2" => "Reset" }.to_json, "StatusCallback" => "https://www.devbatista.online/webhooks/twilio/status" })

    sid = client.send_template_message(to: "+14155552671", content_sid: "HX1", variables: { "1" => "Jane", "2" => "Reset" },
                                       status_callback: "https://www.devbatista.online/webhooks/twilio/status")

    expect(sid).to eq("SM123")
    expect(stub).to have_been_requested
  end

  it "63xxx/21xxx → PermanentError com código; 20429 e 5xx → TransientError; timeout → TransientError (T29)" do
    stub_twilio_error(code: 63016, message: "Failed to send freeform message")
    expect { send_message }.to raise_error(Providers::Twilio::Client::ApiError) { |e| expect(e.code).to eq(63016); expect(e.message).to include("63016") }

    stub_twilio_error(code: 21211, message: "Invalid 'To' Phone Number")
    expect { send_message }.to raise_error(Providers::PermanentError, /21211/)

    stub_twilio_error(code: 20429, message: "Too Many Requests", http_status: 429)
    expect { send_message }.to raise_error(Providers::TransientError, /20429/)

    stub_request(:post, TwilioStubs::MESSAGES_URL).to_return(status: 503, body: "unavailable")
    expect { send_message }.to raise_error(Providers::TransientError)

    stub_request(:post, TwilioStubs::MESSAGES_URL).to_timeout
    expect { send_message }.to raise_error(Providers::TransientError, /expired|Timeout/)
  end

  it "valida X-Twilio-Signature com HMAC-SHA1 e rejeita assinatura alterada, ausente ou de outro token (T29)" do
    url = "https://www.devbatista.online/webhooks/twilio/status"
    params = { "MessageSid" => "SM1", "MessageStatus" => "delivered", "To" => "whatsapp:+14155552671" }
    signature = twilio_signature(url, params)

    expect(client.valid_signature?(url:, params:, signature:)).to be(true)
    expect(client.valid_signature?(url:, params: params.merge("MessageStatus" => "failed"), signature:)).to be(false)
    expect(client.valid_signature?(url: "#{url}?x=1", params:, signature:)).to be(false)
    expect(client.valid_signature?(url:, params:, signature: nil)).to be(false)
    expect(client.valid_signature?(url:, params:, signature: twilio_signature(url, params, auth_token: "other"))).to be(false)
  end

  def send_message
    client.send_template_message(to: "+14155552671", content_sid: "HX1", variables: {}, status_callback: "https://x/cb")
  end
end
