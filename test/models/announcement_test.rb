require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "is active by default" do
    a = Announcement.new(author: users(:one))
    assert a.active?
  end

  test "active scope returns only active announcements" do
    active = Announcement.create!(author: users(:one), active: true)
    inactive = Announcement.create!(author: users(:one), active: false)
    assert_includes Announcement.active, active
    refute_includes Announcement.active, inactive
  end

  test "requires an author" do
    a = Announcement.new(active: true)
    assert_not a.valid?
    assert_includes a.errors[:author], "must exist"
  end

  test "logs a moderation entry on create" do
    assert_difference -> { ModerationLog.where(action: "announcement_created").count }, 1 do
      Announcement.create!(author: users(:one), active: true)
    end
  end
end
