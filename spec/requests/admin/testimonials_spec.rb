require "rails_helper"

RSpec.describe "Admin testimonials" do
  it_behaves_like "coleção do produto no admin", collection: :testimonials, factory: :testimonial,
                  valid: { author_name: "Marta K.", author_role: "Designer", quote: "I finally shipped it." },
                  invalid: { author_name: "", quote: "" }, label_field: :author_name
end
