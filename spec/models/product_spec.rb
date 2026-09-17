require "rails_helper"

RSpec.describe Product do
  describe "associações e anexos" do
    it { is_expected.to have_many(:benefits).dependent(:destroy) }
    it { is_expected.to have_many(:testimonials).dependent(:destroy) }
    it { is_expected.to have_many(:faqs).dependent(:destroy) }
    it { is_expected.to have_one_attached(:pdf_file) }
    it { is_expected.to have_one_attached(:cover_image) }
    it { is_expected.to have_one_attached(:mockup_image) }
    it { is_expected.to have_one_attached(:og_image) }
    it { is_expected.to have_many_attached(:preview_images) }
    it { is_expected.to have_rich_text(:description) }
  end

  describe "validações" do
    subject { build(:product) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:headline) }
    it { is_expected.to validate_numericality_of(:price_cents).only_integer.is_greater_than(0) }
    it { is_expected.to define_enum_for(:status).with_values(draft: "draft", published: "published", archived: "archived").backed_by_column_of_type(:string) }

    it "nasce como draft" do
      expect(described_class.new).to be_draft
    end

    it "não aceita preço zero" do
      expect(build(:product, price_cents: 0)).not_to be_valid
    end

    it "exige compare_at_price maior que o preço" do
      product = build(:product, price_cents: 1490, compare_at_price_cents: 1490)

      expect(product).not_to be_valid
      expect(product.errors[:compare_at_price_cents]).to be_present
      expect(build(:product, price_cents: 1490, compare_at_price_cents: 2900)).to be_valid
      expect(build(:product, price_cents: 1490, compare_at_price_cents: nil)).to be_valid
    end
  end

  describe "slug" do
    it "é gerado a partir do nome quando vazio" do
      product = create(:product, name: "21-Day Procrastination Reset", slug: nil)

      expect(product.slug).to eq("21-day-procrastination-reset")
    end

    it "normaliza para minúsculas e sem espaços" do
      product = create(:product, slug: "  My-Slug ")

      expect(product.slug).to eq("my-slug")
    end

    it "é único" do
      create(:product, slug: "reset")

      expect(build(:product, slug: "reset")).not_to be_valid
    end

    it "só aceita [a-z0-9-]" do
      expect(build(:product, slug: "with_underscore")).not_to be_valid
      expect(build(:product, slug: "acentuação")).not_to be_valid
      expect(build(:product, slug: "ok-123")).to be_valid
    end

    it "recusa slugs reservados (T24)" do
      Product::RESERVED_SLUGS.each do |slug|
        product = build(:product, slug:)

        expect(product).not_to be_valid, "#{slug} deveria ser reservado"
        expect(product.errors[:slug]).to be_present
      end
    end

    it "é usado em to_param" do
      expect(build(:product, slug: "reset").to_param).to eq("reset")
    end
  end

  describe "preço em dólares" do
    it "converte para centavos sem float" do
      product = build(:product)
      product.price = "14.90"
      product.compare_at_price = "29"

      expect(product.price_cents).to eq(1490)
      expect(product.compare_at_price_cents).to eq(2900)
      expect(product.price).to eq(BigDecimal("14.90"))
    end

    it "limpa compare_at quando vazio" do
      product = build(:product, compare_at_price_cents: 2900)
      product.compare_at_price = ""

      expect(product.compare_at_price_cents).to be_nil
    end
  end

  describe "anexos" do
    let(:product) { create(:product) }

    it "aceita PDF e imagens válidos" do
      product.pdf_file.attach(pdf_upload)
      product.cover_image.attach(image_upload)
      product.preview_images.attach([ image_upload, image_upload ])

      expect(product).to be_valid
      expect(product.reload.preview_images.count).to eq(2)
    end

    it "rejeita PDF com content type errado" do
      product.pdf_file.attach(text_upload)

      expect(product).not_to be_valid
      expect(product.errors[:pdf_file]).to include("deve ser um arquivo PDF")
      expect(product.reload.pdf_file).not_to be_attached
    end

    it "rejeita imagem com content type errado" do
      product.mockup_image.attach(text_upload)

      expect(product.errors[:mockup_image]).to include("deve ser JPEG, PNG ou WebP")
      expect(product.reload.mockup_image).not_to be_attached
    end

    it "rejeita PDF acima de 50 MB" do
      product.pdf_file.attach(pdf_upload)
      allow(product.pdf_file.blob).to receive(:byte_size).and_return(Product::PDF_MAX_BYTES + 1)

      expect(product).not_to be_valid
      expect(product.errors[:pdf_file]).to include("deve ter no máximo 50 MB")
    end

    it "rejeita mais de 8 previews" do
      product.preview_images.attach(Array.new(Product::PREVIEW_IMAGES_MAX + 1) { image_upload })

      expect(product.errors[:preview_images]).to include("aceita no máximo 8 imagens")
      expect(product.reload.preview_images).not_to be_attached
    end
  end

  describe "imagens da LP" do
    it "usa o mockup no hero, ou a capa na falta dele" do
      product = build(:product)
      product.cover_image.attach(image_upload)
      expect(product.hero_image).to eq(product.cover_image)

      product.mockup_image.attach(image_upload)
      expect(product.hero_image).to eq(product.mockup_image)
    end

    it "usa a og_image como imagem social, ou a do hero na falta dela" do
      product = build(:product, :with_images)
      expect(product.social_image).to eq(product.mockup_image)

      product.og_image.attach(image_upload)
      expect(product.social_image).to eq(product.og_image)
    end
  end

  describe "template" do
    it "só aceita templates existentes" do
      expect(build(:product, template: "direct_response")).to be_valid
      expect(build(:product, template: "nope")).not_to be_valid
    end
  end

  describe "publicação" do
    it "lista o que falta para publicar" do
      product = create(:product)

      expect(product.missing_for_publish).to contain_exactly("PDF do produto", "imagem de capa ou mockup", "ao menos um benefício")
      expect(product).not_to be_publishable
    end

    it "não publica sem PDF e mantém draft (T23)" do
      product = create(:product, :with_images)
      create(:benefit, product:)

      expect(product.publish).to be(false)
      expect(product.errors[:status].first).to include("PDF do produto")
      expect(product.reload).to be_draft
      expect(product.published_at).to be_nil
    end

    it "publica quando completo e registra published_at" do
      product = create(:product, :with_pdf, :with_images)
      create(:benefit, product:)

      expect(product.publish).to be(true)
      expect(product.reload).to be_published
      expect(product.published_at).to be_within(2.seconds).of(Time.current)
    end

    it "a factory :published é válida" do
      expect(create(:product, :published)).to be_published
    end

    it "despublica e arquiva" do
      product = create(:product, :published)

      expect(product.unpublish).to be(true)
      expect(product.reload).to be_draft
      expect(product.archive).to be(true)
      expect(product.reload).to be_archived
    end
  end
end
