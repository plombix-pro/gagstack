class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post, counter_cache: true
  has_many :comment_votes, dependent: :destroy
  has_many :flags, as: :flaggable, dependent: :destroy

  validates :body, presence: true, length: { maximum: 5000 }

  scope :visible, -> { where(hidden: false) }

  def user_vote(user)
    comment_votes.find_by(user: user)&.upvoted
  end
end
