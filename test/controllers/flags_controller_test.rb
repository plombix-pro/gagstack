require "test_helper"

class FlagsControllerTest < ActionDispatch::IntegrationTest
  test "cannot flag with an arbitrary constantized type" do
    sign_in_as(users(:two))
    assert_no_difference -> { Flag.count } do
      post flags_path, params: {
        flag: { flaggable_type: "User", flaggable_id: users(:one).id, reason: "hack" }
      }
    end
    assert_response :redirect
  end

  test "can flag a post with the whitelisted type" do
    sign_in_as(users(:two))
    assert_difference -> { Flag.count }, 1 do
      post flags_path, params: {
        flag: { flaggable_type: "Post", flaggable_id: posts(:one).id, reason: "spam" }
      }
    end
    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end
