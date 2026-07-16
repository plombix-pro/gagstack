class Category < ApplicationRecord
  has_many :posts, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  scope :ordered, -> { order(position: :asc) }

  def to_param
    slug.presence || id.to_s
  end
end
