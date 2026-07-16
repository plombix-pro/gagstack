class Flag < ApplicationRecord
  belongs_to :user
  belongs_to :flaggable, polymorphic: true

  enum :status, { pending: "pending", reviewed: "reviewed", dismissed: "dismissed" }

  validates :reason, presence: true, length: { maximum: 1000 }
end
