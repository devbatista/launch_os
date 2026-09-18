require "rails_helper"

RSpec.describe Whatsapp::SendTemplateMessage, :twilio do
  it "monta as 4 variáveis (nome, produto, link /download/:token, dias) e o callback público" do
    client = create(:client, :with_whatsapp_opt_in, name: "Jane Buyer")
    order = create(:order, :paid, client:)
    token = create(:download_token, order:)
    stub = stub_twilio_message(sid: "SM9").with(body: hash_including(
      "To" => "whatsapp:+14155552671", "ContentSid" => "HXtest000000000000000000000000000",
      "ContentVariables" => { "1" => "Jane", "2" => order.product.name, "3" => "http://www.example.com/download/#{token.token}", "4" => "7" }.to_json,
      "StatusCallback" => "http://www.example.com/webhooks/twilio/status"
    ))

    expect(described_class.call(order)).to eq("SM9")
    expect(stub).to have_been_requested
  end

  it "sem token ativo levanta ArgumentError (não manda link morto)" do
    order = create(:order, :paid, client: create(:client, :with_whatsapp_opt_in))
    create(:download_token, :revoked, order:)
    expect { described_class.call(order) }.to raise_error(ArgumentError, /no active download token/)
  end
end
