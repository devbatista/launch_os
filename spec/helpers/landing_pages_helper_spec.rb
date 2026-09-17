require "rails_helper"

RSpec.describe LandingPagesHelper do
  describe "#image_dimensions" do
    it "reduz proporcionalmente ao limite sem ampliar" do
      big = instance_double(ActiveStorage::Blob, metadata: { "width" => 1800, "height" => 1200 })
      small = instance_double(ActiveStorage::Blob, metadata: { "width" => 300, "height" => 400 })

      expect(helper.image_dimensions(big, [ 900, 900 ])).to eq(width: 900, height: 600)
      expect(helper.image_dimensions(small, [ 900, 900 ])).to eq(width: 300, height: 400)
    end
  end

  describe "#lp_image_tag" do
    it "sai sem width/height enquanto o blob não foi analisado" do
      product = create(:product, :with_images)

      html = helper.lp_image_tag(product.mockup_image, :lp, limit: [ 900, 900 ], alt: "Mockup")

      expect(html).to include('alt="Mockup"', 'loading="lazy"', "/representations/proxy/")
      expect(html).not_to include("width=")
    end
  end
end
