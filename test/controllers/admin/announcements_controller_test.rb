require "test_helper"

class Admin::AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_path, params: { email_address: @admin.email_address, password: "password" }
  end

  test "admin can list announcements" do
    get admin_announcements_path
    assert_response :success
  end

  test "non-admin is denied" do
    delete session_path
    regular = users(:one)
    post session_path, params: { email_address: regular.email_address, password: "password" }
    get admin_announcements_path
    assert_redirected_to root_path
  end

  test "admin can create an active announcement" do
    assert_difference -> { Announcement.count }, 1 do
      post admin_announcements_path, params: {
        announcement: { active: "1", content: "<strong>Hello</strong> mods" }
      }
    end
    assert_redirected_to admin_announcements_path
    assert Announcement.last.active?
  end

  test "admin can toggle active off via update" do
    a = Announcement.create!(author: @admin, active: true)
    patch admin_announcement_path(a), params: { announcement: { active: "0" } }
    assert_redirected_to admin_announcements_path
    assert_not a.reload.active?
  end

  test "admin can destroy an announcement" do
    a = Announcement.create!(author: @admin, active: true)
    assert_difference -> { Announcement.count }, -1 do
      delete admin_announcement_path(a)
    end
    assert_redirected_to admin_announcements_path
  end
end
