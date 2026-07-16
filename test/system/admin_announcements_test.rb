require "application_system_test_case"

class AdminAnnouncementsTest < ApplicationSystemTestCase
  test "admin creates an announcement visible to a moderator" do
    admin = users(:admin)
    sign_in_as(admin)

    visit new_admin_announcement_path
    check "announcement_active"
    find("trix-editor").click
    find("trix-editor").set("Mods: new rule in effect")
    click_on "Save"

    assert_text "Announcement created"
    assert_text "new rule"

    # A moderator now sees the banner at the top
    moderator = users(:moderator)
    sign_in_as(moderator)
    visit mod_root_path
    within "div.border-amber-500" do
      assert_text "new rule"
    end
  end
end
