# Produto digital vendido pela LP (docs/specs/03-modelo-de-dados.md, 05-catalogo-produtos-admin.md).
# Dinheiro sempre em centavos; o preço cobrado vem daqui, nunca do navegador.
class Product < ApplicationRecord
  # Rotas fixas que `GET /:slug` não pode capturar (spec 06/12).
  RESERVED_SLUGS = %w[admin checkout webhooks download thank-you access privacy terms refund-policy up rails assets].freeze
  SLUG_FORMAT = /\A[a-z0-9-]+\z/

  PDF_CONTENT_TYPE = "application/pdf"
  PDF_MAX_BYTES = 50.megabytes
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  IMAGE_MAX_BYTES = 5.megabytes
  PREVIEW_IMAGES_MAX = 8

  has_many :benefits, -> { ordered }, dependent: :destroy, inverse_of: :product
  has_many :testimonials, -> { ordered }, dependent: :destroy, inverse_of: :product
  has_many :faqs, -> { ordered }, dependent: :destroy, inverse_of: :product

  has_rich_text :description

  has_one_attached :pdf_file
  has_one_attached :cover_image do |a|
    a.variant :lp, resize_to_limit: [ 900, 900 ], format: :webp, saver: { quality: 82 }, preprocessed: true
  end
  has_one_attached :mockup_image do |a|
    a.variant :lp, resize_to_limit: [ 900, 900 ], format: :webp, saver: { quality: 82 }, preprocessed: true
  end
  has_one_attached :og_image
  has_many_attached :preview_images do |a|
    a.variant :thumb, resize_to_limit: [ 600, 800 ], format: :webp, preprocessed: true
  end

  enum :status, { draft: "draft", published: "published", archived: "archived" }, default: :draft

  normalizes :slug, with: ->(s) { s.to_s.strip.downcase }

  before_validation :generate_slug, on: :create

  validates :name, :headline, :slug, :currency, presence: true
  validates :slug, uniqueness: true, format: { with: SLUG_FORMAT, message: "só pode ter letras minúsculas, números e hífens" },
                   exclusion: { in: RESERVED_SLUGS, message: "é reservado pela aplicação" }
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :compare_at_price_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :refund_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, length: { is: 3 }

  validate :compare_at_price_greater_than_price
  validate :pdf_file_format
  validate :image_formats
  validate :publishable_when_published

  scope :recent, -> { order(created_at: :desc) }

  def to_param = slug

  # Preço em dólares como decimal (para exibição/formulário). Sem float: BigDecimal.
  def price = price_cents.to_d / 100
  def compare_at_price = compare_at_price_cents&.then { |c| c.to_d / 100 }

  def price=(value)
    self.price_cents = dollars_to_cents(value)
  end

  def compare_at_price=(value)
    self.compare_at_price_cents = value.blank? ? nil : dollars_to_cents(value)
  end

  # Regras para publicar (spec 05): PDF, uma imagem principal, headline, preço > 0 e ≥ 1 benefício.
  def missing_for_publish
    [].tap do |missing|
      missing << "PDF do produto" unless pdf_file.attached?
      missing << "imagem de capa ou mockup" unless cover_image.attached? || mockup_image.attached?
      missing << "headline" if headline.blank?
      missing << "preço maior que zero" unless price_cents.to_i.positive?
      missing << "ao menos um benefício" unless benefits.any?
    end
  end

  def publishable? = missing_for_publish.empty?

  def publish
    self.status = :published
    self.published_at ||= Time.current
    save
  end

  def unpublish
    update(status: :draft)
  end

  def archive
    update(status: :archived)
  end

  private
    def generate_slug
      self.slug = name.to_s.parameterize if slug.blank? && name.present?
    end

    def dollars_to_cents(value)
      (BigDecimal(value.to_s.strip.delete(",").presence || "0") * 100).round.to_i
    rescue ArgumentError
      nil
    end

    def compare_at_price_greater_than_price
      return if compare_at_price_cents.nil? || price_cents.nil?
      errors.add(:compare_at_price_cents, "deve ser maior que o preço") unless compare_at_price_cents > price_cents
    end

    def pdf_file_format
      return unless pdf_file.attached?

      blob = pdf_file.blob
      errors.add(:pdf_file, "deve ser um arquivo PDF") unless blob.content_type == PDF_CONTENT_TYPE
      errors.add(:pdf_file, "deve ter no máximo 50 MB") if blob.byte_size > PDF_MAX_BYTES
    end

    def image_formats
      { cover_image:, mockup_image:, og_image: }.each do |attribute, attachment|
        validate_image(attribute, attachment.blob) if attachment.attached?
      end

      if preview_images.attached?
        errors.add(:preview_images, "aceita no máximo #{PREVIEW_IMAGES_MAX} imagens") if preview_images.count > PREVIEW_IMAGES_MAX
        preview_images.each { |image| validate_image(:preview_images, image.blob) }
      end
    end

    def validate_image(attribute, blob)
      errors.add(attribute, "deve ser JPEG, PNG ou WebP") unless IMAGE_CONTENT_TYPES.include?(blob.content_type)
      errors.add(attribute, "deve ter no máximo 5 MB") if blob.byte_size > IMAGE_MAX_BYTES
    end

    def publishable_when_published
      return unless published?

      missing = missing_for_publish
      errors.add(:status, "não pode ser publicado sem: #{missing.join(', ')}") if missing.any?
    end
end
