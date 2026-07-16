class CommentVote < ApplicationRecord
  belongs_to :user
  belongs_to :comment

  validates :upvoted, inclusion: { in: [true, false] }
  validates :user_id, uniqueness: { scope: :comment_id }
end
