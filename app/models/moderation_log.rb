class ModerationLog < ApplicationRecord
  belongs_to :moderator, class_name: "User"

  validates :action, presence: true
end
