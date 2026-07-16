class Announcement < ApplicationRecord
  has_rich_text :content
  belongs_to :author, class_name: "User"

  scope :active, -> { where(active: true) }

  after_create :log_creation
  after_destroy :log_destruction

  private

  def log_creation
    ModerationLog.create!(
      moderator: author,
      action: "announcement_created",
      target_type: "Announcement",
      target_id: id,
      details: { active: active }
    )
  end

  def log_destruction
    ModerationLog.create!(
      moderator: author,
      action: "announcement_deleted",
      target_type: "Announcement",
      target_id: id,
      details: {}
    )
  end
end
