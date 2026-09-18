# Stubs WebMock da REST API da Twilio — nenhuma chamada real nos specs (spec 09). Tag `:twilio` liga o
# canal com credenciais de teste; `twilio_signature` assina um webhook como a Twilio faria.
module TwilioStubs
  ACCOUNT_SID = "ACtest000000000000000000000000000".freeze
  AUTH_TOKEN = "test-auth-token".freeze
  MESSAGES_URL = "#{Providers::Twilio::Client::BASE}/Accounts/#{ACCOUNT_SID}/Messages.json".freeze

  def stub_twilio_message(sid: "SMtest0000000000000000000000000001")
    stub_request(:post, MESSAGES_URL)
      .with(basic_auth: [ ACCOUNT_SID, AUTH_TOKEN ])
      .to_return(status: 201, body: { sid:, status: "queued", error_code: nil, error_message: nil }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_twilio_error(code:, message:, http_status: 400)
    stub_request(:post, MESSAGES_URL)
      .to_return(status: http_status, body: { code:, message:, more_info: "https://www.twilio.com/docs/errors/#{code}", status: http_status }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def twilio_signature(url, params, auth_token: AUTH_TOKEN)
    data = url + params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}#{v}" }.join
    Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", auth_token, data))
  end

  # POST assinado num webhook da Twilio (request spec).
  def post_twilio_webhook(path, params, valid: true)
    url = "http://www.example.com#{path}"
    signature = twilio_signature(url, params, auth_token: valid ? AUTH_TOKEN : "wrong-token")
    post path, params:, headers: { "X-Twilio-Signature" => signature }
  end
end

RSpec.configure do |config|
  config.include TwilioStubs

  config.before(:each, :twilio) do
    stub_const("ENV", ENV.to_h.merge("TWILIO_ENABLED" => "true", "TWILIO_ACCOUNT_SID" => TwilioStubs::ACCOUNT_SID,
                                     "TWILIO_AUTH_TOKEN" => TwilioStubs::AUTH_TOKEN, "TWILIO_WHATSAPP_FROM" => "whatsapp:+14155238886",
                                     "TWILIO_TEMPLATE_ORDER_DELIVERY_SID" => "HXtest000000000000000000000000000",
                                     "APP_HOST" => "www.example.com", "APP_PROTOCOL" => "http"))
  end
end
