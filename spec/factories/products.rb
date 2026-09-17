FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "21-Day Procrastination Reset #{n}" }
    headline { "Stop putting things off — in 21 days" }
    subheadline { "A practical, printable system to rebuild focus." }
    price_cents { 1490 }
    currency { "USD" }
    status { "draft" }

    trait :draft do
      status { "draft" }
    end

    trait :archived do
      status { "archived" }
    end

    trait :with_pdf do
      after(:build) do |product|
        product.pdf_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/product.pdf")),
                                filename: "product.pdf", content_type: "application/pdf")
      end
    end

    trait :with_images do
      after(:build) do |product|
        product.cover_image.attach(io: File.open(Rails.root.join("spec/fixtures/files/image.png")),
                                   filename: "cover.png", content_type: "image/png")
        product.mockup_image.attach(io: File.open(Rails.root.join("spec/fixtures/files/image.png")),
                                    filename: "mockup.png", content_type: "image/png")
      end
    end

    trait :with_lp_content do
      problem_text { "You know what to do. You just don't start." }
      guarantee_text { "14-day money-back guarantee, no questions asked." }
      description { "<p>Twenty-one days of small, concrete steps.</p>" }
      after(:create) do |product|
        create_list(:benefit, 3, product:)
        create_list(:testimonial, 2, product:)
        create_list(:faq, 2, product:)
      end
    end

    # Produto completo e publicável: PDF, imagens, conteúdo e ≥ 1 benefício.
    trait :published do
      with_pdf
      with_images
      status { "published" }
      published_at { Time.current }
      after(:build) { |product| product.benefits.build(title: "Daily 10-minute ritual") }
    end
  end

  factory :benefit do
    product
    sequence(:title) { |n| "Benefit #{n}" }
    description { "Why this matters." }
  end

  factory :testimonial do
    product
    sequence(:author_name) { |n| "Reader #{n}" }
    author_role { "Freelance designer" }
    quote { "I finally shipped the thing I'd been avoiding for months." }
  end

  factory :faq do
    product
    sequence(:question) { |n| "Question #{n}?" }
    answer { "A short, honest answer." }
  end
end
