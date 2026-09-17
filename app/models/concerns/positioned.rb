# Itens ordenáveis dentro de um produto (benefits, testimonials, faqs — spec 03/05).
# `position` é 1-based e sequencial por produto; novo item entra no fim. `move(:up|:down)`
# troca de lugar com o vizinho (setas ↑/↓ do admin, sem drag-and-drop).
module Positioned
  extend ActiveSupport::Concern

  included do
    belongs_to :product, touch: true # invalida o ETag da LP (`fresh_when(@product)`)

    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :assign_position, on: :create

    scope :ordered, -> { order(:position, :created_at) }
  end

  def move(direction)
    neighbor = case direction.to_s
    when "up"   then siblings.where(position: ...position).ordered.last
    when "down" then siblings.where(position: (position + 1)..).ordered.first
    else raise ArgumentError, "direction must be up or down"
    end
    return false unless neighbor

    transaction do
      mine = position
      update!(position: neighbor.position)
      neighbor.update!(position: mine)
    end
    true
  end

  private
    def siblings
      self.class.where(product_id:).where.not(id:)
    end

    def assign_position
      return if position.present? && position.positive?
      self.position = (self.class.where(product_id:).maximum(:position) || 0) + 1
    end
end
