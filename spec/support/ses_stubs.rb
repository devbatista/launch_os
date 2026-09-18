# SDK do SES com respostas stubadas (nenhuma chamada real) para Providers::Ses::Client / :ses_api.
module SesStubs
  # `send_email:` aceita um hash de resposta ({ message_id: }) ou uma classe/instância de erro do SDK.
  def stubbed_ses_sdk(send_email: { message_id: "ses-msg-1" })
    Aws::SESV2::Client.new(stub_responses: { send_email: }, region: "us-east-1", credentials: Aws::Credentials.new("k", "s"), retry_limit: 0)
  end

  def ses_client(**)
    Providers::Ses::Client.new(sdk: stubbed_ses_sdk(**), access_key_id: "k", secret_access_key: "s", configuration_set: "launch-os")
  end
end

RSpec.configure { |c| c.include SesStubs }
