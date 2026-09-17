require "rails_helper"

RSpec.describe "Admin benefits" do
  it_behaves_like "coleção do produto no admin", collection: :benefits, factory: :benefit,
                  valid: { title: "Daily 10-minute ritual", description: "Small enough to start." },
                  invalid: { title: "", description: "x" }, label_field: :title
end
