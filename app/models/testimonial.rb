class Testimonial < ApplicationRecord
  include Positioned

  validates :author_name, :quote, presence: true
end
