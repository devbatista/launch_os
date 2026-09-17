require "rails_helper"

# Comportamento compartilhado de benefits, testimonials e faqs (concern Positioned).
RSpec.describe Positioned do
  let(:product) { create(:product) }

  [ :benefit, :testimonial, :faq ].each do |factory_name|
    describe factory_name.to_s do
      it "entra no fim da lista do produto" do
        first = create(factory_name, product:)
        second = create(factory_name, product:)
        other_product_item = create(factory_name)

        expect(first.position).to eq(1)
        expect(second.position).to eq(2)
        expect(other_product_item.position).to eq(1)
      end

      it "respeita uma posição informada" do
        expect(create(factory_name, product:, position: 5).position).to eq(5)
      end

      it "move para cima e para baixo trocando com o vizinho" do
        a = create(factory_name, product:)
        b = create(factory_name, product:)
        c = create(factory_name, product:)

        expect(c.move(:up)).to be(true)
        expect([ a, b, c ].map { |i| i.reload.position }).to eq([ 1, 3, 2 ])

        expect(a.move(:down)).to be(true)
        expect([ a, b, c ].map { |i| i.reload.position }).to eq([ 2, 3, 1 ])
      end

      it "não move além das bordas" do
        only = create(factory_name, product:)

        expect(only.move(:up)).to be(false)
        expect(only.move(:down)).to be(false)
        expect { only.move(:sideways) }.to raise_error(ArgumentError)
      end
    end
  end

  it "valida presença dos campos obrigatórios" do
    expect(build(:benefit, title: nil)).not_to be_valid
    expect(build(:testimonial, author_name: nil)).not_to be_valid
    expect(build(:testimonial, quote: nil)).not_to be_valid
    expect(build(:faq, question: nil)).not_to be_valid
    expect(build(:faq, answer: nil)).not_to be_valid
  end

  it "é removido junto com o produto" do
    create(:benefit, product:)
    create(:faq, product:)

    expect { product.destroy }.to change(Benefit, :count).by(-1).and change(Faq, :count).by(-1)
  end
end
