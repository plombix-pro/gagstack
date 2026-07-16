require "application_system_test_case"

class GagStackTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = Category.create!(name: "Test Category", slug: "test-category", position: 1)
    @admin = User.create!(
      email_address: "admin@example.com",
      password: "password",
      username: "admin",
      date_of_birth: 30.years.ago.to_date,
      verified_at: 1.day.ago,
      role: "super_admin",
      reputation: 9999
    )
    ReputationThreshold.find_or_create_by!(name: "view_upvote") { |t| t.min_reputation = 1 }
    ReputationThreshold.find_or_create_by!(name: "post_images") { |t| t.min_reputation = 10 }
    ReputationThreshold.find_or_create_by!(name: "flag_content") { |t| t.min_reputation = 15 }
    ReputationThreshold.find_or_create_by!(name: "comment") { |t| t.min_reputation = 50 }
    ReputationThreshold.find_or_create_by!(name: "downvote") { |t| t.min_reputation = 100 }
    ReputationThreshold.find_or_create_by!(name: "downvote_comment") { |t| t.min_reputation = 250 }
    # Add remaining thresholds from seeds so the profile milestones test works
    ReputationThreshold.find_or_create_by!(name: "change_username") { |t| t.min_reputation = 500 }
    ReputationThreshold.find_or_create_by!(name: "moderate") { |t| t.min_reputation = 500 }
    ReputationThreshold.find_or_create_by!(name: "appeal_flags") { |t| t.min_reputation = 1000 }
    ReputationThreshold.find_or_create_by!(name: "edit_posts") { |t| t.min_reputation = 3000 }
    ReputationThreshold.find_or_create_by!(name: "vote_to_ban") { |t| t.min_reputation = 10000 }
  end

  # Posts require attached media, so tests use this helper to satisfy the
  # media_must_be_attached validation without going through the upload UI.
  def create_post!(**attrs)
    post = Post.new(attrs)
    post.media.attach(io: StringIO.new("x" * 64), filename: "test.jpg", content_type: "image/jpeg")
    post.save!
    post
  end

  # ── Registration ─────────────────────────────────────────────

  test "new user can register, verify email, and log in" do
    FileUtils.rm_rf(Dir.glob(Rails.root.join("tmp/mails/*")))

    visit sign_up_path
    assert_current_path new_age_verification_path

    verify_age

    fill_in "Username", with: "newuser"
    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "password123"
    fill_in "user_date_of_birth", with: 22.years.ago.to_date.iso8601
    click_button "Create account"

    assert_text "Check your email"

    email_file = Dir.glob(Rails.root.join("tmp/mails/*newuser@example.com*")).max
    assert email_file, "Email file not found"
    email_content = File.read(email_file)
    token = email_content[/\/verify\/([a-f0-9]{64})/, 1]
    assert token, "Verification token not found in email"

    visit verification_url(token)
    assert_current_path root_path
    assert_text "Email verified"
  end

  test "underage user cannot register" do
    verify_age

    fill_in "Username", with: "underage"
    fill_in "Email", with: "underage@example.com"
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "password123"
    fill_in "user_date_of_birth", with: 16.years.ago.to_date.iso8601
    click_button "Create account"

    assert_text "must be 18"
  end

  # ── Login / Logout ───────────────────────────────────────────

  test "user can log in with valid credentials" do
    sign_in_as(@user)
    assert_text @user.username
  end

  test "user cannot log in with wrong password" do
    visit new_session_path
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "wrongpassword"
    click_button "Login"
    assert_text "Try another"
  end

  test "unverified user cannot log in" do
    unverified = User.create!(
      email_address: "unverified@example.com",
      password: "password",
      username: "unverified",
      date_of_birth: 25.years.ago.to_date
    )

    visit new_session_path
    fill_in "email_address", with: unverified.email_address
    fill_in "password", with: "password"
    click_button "Login"
    assert_text "verify your email"
  end

  test "banned user cannot log in" do
    @user.update!(banned_at: Time.current)
    visit new_session_path
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "password"
    click_button "Login"
    assert_text "suspended"
  end

  test "user can log out" do
    sign_in_as(@user)
    find("[data-controller='dropdown'] button").click
    click_on "Logout"
    assert_current_path new_session_path
  end

  # ── Posts ────────────────────────────────────────────────────

  test "visitor can see the home feed" do
    visit root_path
    assert_selector "body"
  end

  test "visitor can see individual post" do
    post = create_post!(
      user: @user,
      category: @category,
      title: "Integration test post",
      media_type: "image",
      status: "approved"
    )
    visit post_path(post)
    assert_text "Integration test post"
  end

  test "visitor cannot create a post" do
    visit new_post_path
    assert_current_path new_session_path
  end

  test "logged-in user can create a post" do
    sign_in_as(@user)
    visit new_post_path
    fill_in "Title", with: "System test post"
    select @category.name, from: "Category"
    attach_file "post[media]", Rails.root.join("test/fixtures/files/test.png"), make_visible: true
    # Wait for client-side media processing to finish (sets the media_type field).
    assert_text "Ready!", wait: 15
    click_button "Post"
    assert_text "System test post"
  end

  # ── Browsing ──────────────────────────────────────────────────

  test "visitor can browse a category and see its posts" do
    create_post!(
      user: @user,
      category: @category,
      title: "Category browsing post",
      media_type: "image"
    )
    visit category_posts_path(@category)
    assert_text @category.name
    assert_text "Category browsing post"
  end

  test "categories index lists all categories" do
    visit categories_path
    assert_text "Browse Categories"
    assert_text @category.name
    click_link @category.name
    assert_current_path category_posts_path(@category)
    assert_text @category.name
  end

  test "home feed shows approved posts" do
    create_post!(
      user: @user,
      category: @category,
      title: "Feed visible post",
      media_type: "image"
    )
    visit root_path
    assert_text "Feed visible post"
  end

  # ── Profile ──────────────────────────────────────────────────

  test "visitor can view a user's profile and see their posts" do
    create_post!(
      user: @user,
      category: @category,
      title: "Profile test post",
      media_type: "image",
      status: "approved"
    )

    visit public_profile_path(@user.slug)
    assert_text @user.username
    assert_text "Profile test post"
    assert_text @user.reputation.to_s
  end

  test "profile 404s for unknown username" do
    visit public_profile_path("nonexistent")
    assert_text "RecordNotFound"
  end

  test "profile shows reputation scale and milestones" do
    visit public_profile_path(@user.slug)
    assert_text @user.reputation.to_s
    assert_text "View upvote"
    assert_text "Vote to ban"
    assert_text "Next milestone"
  end

  test "profile tabs filter posts by type" do
    my_post = create_post!(
      user: @user,
      category: @category,
      title: "My own post",
      media_type: "image",
      status: "approved"
    )

    upvoted_post = create_post!(
      user: @admin,
      category: @category,
      title: "Upvoted by user",
      media_type: "image",
      status: "approved"
    )
    Vote.create!(user: @user, post: upvoted_post, upvoted: true)

    commented_post = create_post!(
      user: @admin,
      category: @category,
      title: "Commented by user",
      media_type: "image",
      status: "approved"
    )
    Comment.create!(user: @user, post: commented_post, body: "Nice post!")

    visit public_profile_path(@user.slug)
    assert_text "My own post"
    assert_no_text "Upvoted by user"
    assert_no_text "Commented by user"

    click_on "Upvoted"
    assert_text "Upvoted by user"
    assert_no_text "My own post"
    assert_no_text "Commented by user"

    click_on "Commented"
    assert_text "Commented by user"
    assert_no_text "My own post"
    assert_no_text "Upvoted by user"
  end

  # ── Voting ───────────────────────────────────────────────────

  test "logged-in user can upvote a post" do
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Votable post",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)
    find("[data-action='vote#up']").click
    assert_selector "span[data-vote-target='upvotes']", text: "1", wait: 5
  end

  test "low-rep user cannot downvote" do
    @user.update!(reputation: 1)

    post = create_post!(
      user: @admin,
      category: @category,
      title: "Downvote test",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)
    find("[data-action='vote#down']").click
    assert_equal 0, post.reload.downvotes_count
  end

  test "logged-in user can downvote a post" do
    @user.update!(reputation: 100)

    post = create_post!(
      user: @admin,
      category: @category,
      title: "Downvote test",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)
    find("[data-action='vote#down']").click
    assert_selector "span[data-vote-target='downvotes']", text: "1", wait: 5
  end

  # ── Comments ─────────────────────────────────────────────────

  test "logged-in user can comment on a post" do
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Commentable post",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)

    fill_in "comment[body]", with: "System test comment"
    click_button "Post"
    assert_text "System test comment"
  end

  test "visitor cannot comment" do
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Protected comment post",
      media_type: "image",
      status: "approved"
    )
    visit post_path(post)
    assert_no_field "comment[body]"
  end

  # ── Moderation ───────────────────────────────────────────────

  test "moderator can access mod dashboard" do
    @user.update!(role: "moderator", reputation: 500)
    sign_in_as(@user)
    visit mod_root_path
    assert_text "Moderation Dashboard"
  end

  test "regular user cannot access mod dashboard" do
    sign_in_as(@user)
    visit mod_root_path
    assert_text "Access denied"
  end

  test "moderator can see pending posts" do
    @user.update!(role: "moderator", reputation: 500)
    create_post!(
      user: @admin,
      category: @category,
      title: "Pending post for mod",
      media_type: "image",
      status: "pending"
    )

    sign_in_as(@user)
    visit mod_root_path
    assert_text "Pending post for mod"
  end

  test "moderator can approve a pending post" do
    @user.update!(role: "moderator", reputation: 500)
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Approvable post",
      media_type: "image",
      status: "pending"
    )

    sign_in_as(@user)
    visit mod_root_path
    within "#mod_post_#{post.id}" do
      click_on "Approve"
    end
    assert_no_text "Approvable post"
    assert_equal "approved", post.reload.status
  end

  test "moderator can reject a pending post" do
    @user.update!(role: "moderator", reputation: 500)
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Rejectable post",
      media_type: "image",
      status: "pending"
    )

    sign_in_as(@user)
    visit mod_root_path
    within "#mod_post_#{post.id}" do
      click_on "Reject"
    end
    assert_no_text "Rejectable post"
    assert_equal "rejected", post.reload.status
  end

  # ── Reputation System ────────────────────────────────────────

  test "user with low rep cannot comment" do
    @user.update!(reputation: 1)

    create_post!(
      user: @admin,
      category: @category,
      title: "Low-rep comment test",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit root_path
  end

  test "moderators and admins bypass reputation checks" do
    @user.update!(role: "admin", reputation: 1)
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Admin bypass test",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)
  end

  # ── Administration ───────────────────────────────────────────

  test "super admin can access admin panel" do
    sign_in_as(@admin)
    visit admin_root_path
    assert_text "Admin Panel"
  end

  test "regular user cannot access admin panel" do
    sign_in_as(@user)
    visit admin_root_path
    assert_text "Access denied"
  end

  test "super admin can manage users (ban/unban)" do
    sign_in_as(@admin)
    visit admin_users_path
    assert_text @user.username

    click_on @user.username
    assert_text @user.email_address
  end

  test "super admin can view and edit reputation thresholds" do
    sign_in_as(@admin)
    visit admin_reputation_thresholds_path
    assert_text "View upvote"

    click_on "Edit", match: :first
    assert_selector "input[type='number']"
  end

  test "non-admin cannot edit reputation thresholds" do
    @user.update!(reputation: 5000)
    sign_in_as(@user)
    visit admin_reputation_thresholds_path
    assert_text "Access denied"
  end

  test "super admin can create a category" do
    sign_in_as(@admin)
    visit admin_categories_path
    click_on "New Category"
    fill_in "Name", with: "Test New Category"
    fill_in "Slug", with: "test-new-category"
    fill_in "Position", with: "10"
    click_button "Create Category"
    assert_text "Category created"
    assert_text "Test New Category"
  end

  test "super admin can delete a category" do
    sign_in_as(@admin)
    visit admin_categories_path
    assert_text @category.name
    link = find_link("Delete")
    link.click
    assert_text "Category deleted"
    assert_no_text @category.name
  end

  test "non-admin cannot create categories" do
    sign_in_as(@user)
    visit new_admin_category_path
    assert_text "Access denied"
  end

  # ── Age Verification Gate ────────────────────────────────────

  test "age verification gate blocks direct signup access" do
    Capybara.reset_sessions!
    visit sign_up_path
    assert_current_path new_age_verification_path
  end

  test "manual age verification with valid age works" do
    verify_age
  end

  test "underage user is rejected by manual verification" do
    Capybara.reset_sessions!
    visit new_age_verification_path
    click_on "Or verify manually"
    within "[data-age-verification-target='manualSection']" do
      find("[data-age-verification-target='day']").find("option[value='15']").select_option
      find("[data-age-verification-target='month']").find("option", text: "January").select_option
      find("[data-age-verification-target='year']").find("option[value='#{(Date.today.year - 15)}']").select_option
      click_on "Verify age"
    end
    assert_text "must be 18"
  end

  # ── Search ───────────────────────────────────────────────────

  test "search returns results" do
    create_post!(
      user: @user,
      category: @category,
      title: "Unique searchable post title",
      media_type: "image",
      status: "approved"
    )

    visit search_path(q: "Unique searchable")
    assert_text "Unique searchable post title"
  end

  test "search shows no results message" do
    visit search_path(q: "nonexistentpostthatdoesnotexist")
    assert_text "No results"
  end

  # ── Flags ────────────────────────────────────────────────────

  test "user can flag a post" do
    @user.update!(reputation: 20)
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Flaggable post",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)
    find("[data-post-flag] a", text: "Flag").click
    find("[data-flag-form] textarea").set("Inappropriate content")
    click_button "Submit flag"
    assert_text "Flagged for review"
    assert_equal 1, Flag.count
    assert_equal "pending", Flag.last.status
  end

  test "low-rep user cannot see flag button" do
    @user.update!(reputation: 1)
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Protected post",
      media_type: "image",
      status: "approved"
    )

    sign_in_as(@user)
    visit post_path(post)
    assert_no_text "Flag"
  end

  test "user can flag a comment" do
    @user.update!(reputation: 20)
    post = create_post!(
      user: @admin,
      category: @category,
      title: "Comment flag test",
      media_type: "image",
      status: "approved"
    )
    comment = Comment.create!(user: @admin, post: post, body: "Objectionable comment")

    sign_in_as(@user)
    visit post_path(post)
    within "#comment_#{comment.id}" do
      find("a", text: "Flag").click
      fill_in "flag[reason]", with: "Spam"
      click_button "Go"
    end
    assert_text "Flagged for review"
    assert_equal 1, Flag.count
  end

  # ── Already-logged-in redirects ─────────────────────────────

  test "logged-in user visiting sign in is redirected to root" do
    sign_in_as(@user)
    visit new_session_path
    assert_current_path root_path
    assert_text "already signed in"
  end

  test "logged-in user visiting sign up is redirected to root" do
    sign_in_as(@user)
    visit sign_up_path
    assert_current_path root_path
    assert_text "already signed in"
  end
end
