# Helpers da LP pública (docs/specs/06-landing-page.md). Textos em inglês (AGENTS.md).
module LandingPagesHelper
  def paypal_client_id = ENV.fetch("PAYPAL_CLIENT_ID", "")
  def twilio_enabled? = ENV["TWILIO_ENABLED"] == "true"

  # Meta Pixel e GA4 (spec 10): só com o id configurado e nunca no preview do admin.
  def meta_pixel_id = @preview ? nil : ENV["META_PIXEL_ID"].presence
  def ga4_measurement_id = @preview ? nil : ENV["GA4_MEASUREMENT_ID"].presence

  # <img> de um anexo com variant WebP, `alt`, `loading` e width/height explícitos (evita layout shift).
  # As dimensões vêm dos metadados do blob (AnalyzeJob) reduzidas ao limite do variant; sem metadados
  # ainda, o `<img>` sai sem width/height e o CSS (aspect-ratio/object-fit) segura o layout.
  def lp_image_tag(attached, variant, limit:, alt:, loading: "lazy", **options)
    blob = attached.blob
    options = options.merge(alt:, loading:, decoding: "async")
    options = options.merge(image_dimensions(blob, limit)) if blob.metadata["width"] && blob.metadata["height"]
    image_tag url_for(attached.variant(variant)), **options
  end

  # Dimensões finais de um `resize_to_limit`: reduz proporcionalmente, nunca amplia.
  def image_dimensions(blob, limit)
    width, height = blob.metadata.values_at("width", "height").map(&:to_f)
    scale = [ limit[0] / width, limit[1] / height, 1.0 ].min
    { width: (width * scale).round, height: (height * scale).round }
  end

  # URL absoluta da imagem social: og_image (1200×630 JPEG) ou, na falta, a imagem do hero.
  def og_image_url(product)
    image = product.social_image
    variant = product.og_image.attached? ? image.variant(:og) : image.variant(:lp)
    rails_storage_proxy_url(variant)
  end

  def support_email = ENV.fetch("SUPPORT_EMAIL", "support@devbatista.online")
end
