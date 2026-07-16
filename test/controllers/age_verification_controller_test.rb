require "test_helper"

class AgeVerificationTest < ActionDispatch::IntegrationTest
  test "rejects client-spoofed AI estimated age" do
    post age_verification_path, params: { method: "ai", estimated_age: 99 }, as: :json
    assert_response :forbidden
    assert_not session[:age_verified]
  end

  test "accepts a valid server-validated date of birth" do
    dob = 20.years.ago.to_date.iso8601
    post age_verification_path, params: { method: "manual", dob: dob }, as: :json
    assert_response :ok
    assert session[:age_verified]
  end

  test "rejects an underage date of birth" do
    dob = 10.years.ago.to_date.iso8601
    post age_verification_path, params: { method: "manual", dob: dob }, as: :json
    assert_response :forbidden
    assert_not session[:age_verified]
  end
end
