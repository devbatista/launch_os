require "rails_helper"

RSpec.describe "Admin faqs" do
  it_behaves_like "coleção do produto no admin", collection: :faqs, factory: :faq,
                  valid: { question: "Is this a course?", answer: "No, a PDF." },
                  invalid: { question: "", answer: "" }, label_field: :question
end
