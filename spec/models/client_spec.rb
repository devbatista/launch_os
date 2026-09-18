require "rails_helper"

RSpec.describe Client do
  it "normaliza o email e impõe unicidade sem distinguir maiúsculas" do
    create(:client, email: "  Jane@Example.com ")

    expect(described_class.sole.email).to eq("jane@example.com")
    expect(build(:client, email: "JANE@example.com")).not_to be_valid
    expect { described_class.create!(email: "jane@EXAMPLE.com") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "valida email e telefone" do
    expect(build(:client, email: "nope")).not_to be_valid
    expect(build(:client, phone: "123")).not_to be_valid
    expect(build(:client, phone: "+14155552671")).to be_valid
  end

  it "só entrega no WhatsApp com opt-in, telefone e sem opt-out" do
    expect(build(:client)).not_to be_whatsapp_deliverable
    expect(build(:client, :with_whatsapp_opt_in)).to be_whatsapp_deliverable
    expect(build(:client, :opted_out)).not_to be_whatsapp_deliverable

    client = create(:client, :with_whatsapp_opt_in)
    client.opt_out_whatsapp!
    expect(client.reload).not_to be_whatsapp_deliverable
    expect(client.whatsapp_opt_out_at).to be_present
  end
end
