class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :post

  validates :upvoted, inclusion: { in: [true, false] }
  validates :user_id, uniqueness: { scope: :post_id }
end
