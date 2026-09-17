# Helpers para anexar fixtures de spec/fixtures/files a registros nos specs.
module AttachmentHelpers
  FIXTURES = Rails.root.join("spec/fixtures/files")

  def fixture_upload(name, content_type)
    Rack::Test::UploadedFile.new(FIXTURES.join(name), content_type)
  end

  def pdf_upload = fixture_upload("product.pdf", "application/pdf")
  def image_upload = fixture_upload("image.png", "image/png")
  def text_upload = fixture_upload("not-an-image.txt", "text/plain")
end

RSpec.configure { |config| config.include AttachmentHelpers }
