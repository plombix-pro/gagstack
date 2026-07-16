require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "user cannot re-circulate another post's already-published media" do
    published = posts(:one)
    published.media.attach(io: File.open(file_fixture("test.png")), filename: "test.png", content_type: "image/png")
    reused_signed_id = published.media.blob.signed_id

    sign_in_as(users(:two))

    assert_no_difference -> { ActiveStorage::Attachment.where(name: "media").count } do
      post posts_path, params: {
        post: {
          title: "Reusing someone else media",
          category_id: categories(:one).id,
          media_type: "image"
        },
        media_signed_id: reused_signed_id
      }
    end

    created = Post.find_by(title: "Reusing someone else media")
    refute created&.media&.attached?, "post must not be created with a reused blob"
  end

  test "user can attach a fresh uploaded file" do
    sign_in_as(users(:two))

    assert_difference -> { ActiveStorage::Attachment.where(name: "media").count }, 1 do
      post posts_path, params: {
        post: {
          title: "Brand new post",
          category_id: categories(:one).id,
          media_type: "image",
          media: Rack::Test::UploadedFile.new(file_fixture("test.png").to_s, "image/png")
        }
      }
    end

    assert_redirected_to Post.find_by(title: "Brand new post")
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end
