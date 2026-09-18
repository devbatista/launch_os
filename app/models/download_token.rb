# Acesso ao PDF de um pedido (docs/specs/08-entrega-download-tokens.md). O arquivo nunca tem URL pública:
# o token leva à Thank You e ao download, que redireciona para uma URL assinada de 5 minutos.
# Só funciona com o pedido `paid`, dentro do prazo, sem revogação e abaixo do limite de downloads.
class DownloadToken < ApplicationRecord
  belongs_to :order

  has_secure_token :token, length: 36

  validates :expires_at, presence: true
  validates :download_count, :max_downloads, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  after_initialize :apply_defaults, if: :new_record?

  def self.ttl = ENV.fetch("DOWNLOAD_TOKEN_TTL_DAYS", 7).to_i.days
  def self.default_max_downloads = ENV.fetch("DOWNLOAD_MAX_COUNT", 10).to_i

  def active? = inactive_reason.nil?

  # :revoked | :not_paid | :expired | :limit_reached | nil. Revogado vem antes de não-pago: após refund
  # ou disputa o pedido deixa de ser paid e a resposta certa é 410 (revogado), não 402.
  def inactive_reason
    return :revoked if revoked_at.present?
    return :not_paid unless order.paid?
    return :expired unless expires_at.future?
    return :limit_reached if download_count >= max_downloads

    nil
  end

  def remaining_downloads = [ max_downloads - download_count, 0 ].max

  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
    self
  end

  # Novo token, prazo renovado, contador zerado e revogação limpa — só para pedido pago (spec 08).
  def regenerate!
    raise ArgumentError, "cannot regenerate the token of a #{order.status} order" unless order.paid?

    update!(token: self.class.generate_unique_secure_token(length: 36), expires_at: self.class.ttl.from_now,
            download_count: 0, revoked_at: nil)
    self
  end

  # Um download efetivo: incremento sob lock (dois cliques simultâneos não passam do limite).
  def register_download!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless active?

      update!(download_count: download_count + 1, last_downloaded_at: Time.current)
    end
    self
  end

  private
    def apply_defaults
      self.expires_at ||= self.class.ttl.from_now
      self.max_downloads = self.class.default_max_downloads if max_downloads.nil?
    end
end
