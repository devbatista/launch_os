class Benefit < ApplicationRecord
  include Positioned

  validates :title, presence: true
end
