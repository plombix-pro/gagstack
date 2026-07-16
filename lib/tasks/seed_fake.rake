desc "Seed fake users, posts, votes, and comments for testing"
task seed_fake: :environment do
  require "ffaker"

  puts "Clearing existing data..."
  ActiveRecord::Base.connection.execute("DELETE FROM comment_votes")
  ActiveRecord::Base.connection.execute("DELETE FROM flags")
  ActiveRecord::Base.connection.execute("DELETE FROM moderation_logs")
  Vote.delete_all
  Comment.delete_all
  ActiveStorage::VariantRecord.delete_all
  ActiveStorage::Attachment.delete_all
  ActiveStorage::Blob.delete_all
  Post.destroy_all
  ApiToken.delete_all
  Session.delete_all
  User.where.not(email_address: "admin@gagstack.com").delete_all
  Category.delete_all
  ReputationThreshold.delete_all
  FileUtils.rm_rf(Dir[Rails.root.join("storage", "*")])

  # ── Ensure base data ──────────────────────────────────────────
  categories = %w[Funny Gaming Awesome Cute Wholesome NSFW].map.with_index { |name, i|
    Category.find_or_create_by!(name: name) { |c| c.slug = name.downcase; c.position = i + 1 }
  }

  thresholds_data = [
    { name: "view_upvote", min_reputation: 1, description: "View and upvote content" },
    { name: "post_images", min_reputation: 10, description: "Post images and GIFs" },
    { name: "flag_content", min_reputation: 15, description: "Flag content for moderation" },
    { name: "comment", min_reputation: 50, description: "Comment on any post" },
    { name: "downvote", min_reputation: 100, description: "Downvote posts" },
    { name: "downvote_comment", min_reputation: 250, description: "Downvote comments" },
    { name: "change_username", min_reputation: 500, description: "Change your username" },
    { name: "moderate", min_reputation: 500, description: "Access moderation tools" },
    { name: "appeal_flags", min_reputation: 1000, description: "Appeal flag decisions" },
    { name: "edit_posts", min_reputation: 3000, description: "Edit anyone's posts" },
    { name: "vote_to_ban", min_reputation: 10000, description: "Vote to ban users" },
  ]
  thresholds_data.each { |t|
    ReputationThreshold.find_or_create_by!(name: t[:name]) { |rt| rt.assign_attributes(t) }
  }

  # ── 100 users with realistic reputation distribution ──────────
  rep_distribution = [*1..50].map { rand(1..15) } +
                     [*1..25].map { rand(16..100) } +
                     [*1..15].map { rand(101..500) } +
                     [*1..7].map { rand(501..3000) } +
                     [*1..3].map { rand(3001..10000) }

  users = []
  puts "Creating 100 users..."
  rep_distribution.shuffle.each_with_index do |rep, i|
    username = FFaker::Internet.unique.user_name.gsub(/[^a-zA-Z0-9_]/, "_")[0..20]
    user = User.create!(
      email_address: "#{username}@gagstack.fake",
      password: "password",
      username: username,
      date_of_birth: FFaker::Time.between(50.years.ago, 18.years.ago).to_date,
      verified_at: FFaker::Time.between(30.days.ago, Time.current),
      reputation: rep,
      role: rep >= 500 && rand < 0.3 ? "moderator" : "user"
    )
    users << user
  end
  puts "  #{users.size} users created (rep range: #{users.map(&:reputation).min}–#{users.map(&:reputation).max})"

  # ── Reusable placeholder image (valid 1x1 grey JPEG) ─────────
  placeholder_path = Rails.root.join("tmp", "seed_placeholder.jpg")
  unless placeholder_path.exist?
    system "convert", "-size", "1x1", "xc:gray", placeholder_path.to_s
  end
  placeholder_bytes = placeholder_path.binread
  placeholder_io = -> { StringIO.new(placeholder_bytes).tap(&:binmode) }

  # ── Category-specific post title templates ────────────────────
  post_templates = {
    "Funny"     => ["When you finally fix that bug", "Nobody: ... Me at 3am eating cheese", "This is so me rn",
                    "Expected vs Reality", "My brain during exams", "POV: You're a developer",
                    "The accuracy hurts", "How it started vs how it's going", "I'm in this photo and I don't like it",
                    "Wait, that's illegal"],
    "Gaming"    => ["When the boss has 1HP", "My aim after coffee vs before", "The final boss be like",
                    "Reverse card moment", "Sweatiest lobby ever", "Lag killed me",
                    "When you forget to save", "POV: You're the main character", "Team mate of the year award",
                    "Hitbox porn"],
    "Awesome"   => ["Nature is lit", "This belongs here", "Absolutely beautiful", "Peak engineering",
                    "Satisfying to watch", "r/nextfuckinglevel material", "How is this real",
                    "Art at its finest", "The glow up is real", "This changed my life"],
    "Cute"      => ["My heart can't take this", "Baby doggo alert", "Floof overload",
                    "Look at those eyes", "Tiny paws, big dreams", "He protecc, he attacc",
                    "Cuddle puddle", "The blep is strong with this one", "Wholesome 100",
                    "Best boy/girl 2026"],
    "Wholesome" => ["Made my day", "Faith in humanity restored", "This is why I love the internet",
                    "Wholesome thread alert", "Kindness costs nothing", "A happy ending",
                    "The internet can be beautiful", "Wholesome plot twist", "Humanity is good actually",
                    "Pay it forward"],
    "NSFW"      => ["Mark your calendars", "Not safe for work at all", "Close the tab bro",
                    "Why would you post this", "I need eye bleach", "Risky click of the day",
                    "That escalated quickly", "Bro chill", "Internet was a mistake",
                    "You have been warned"],
  }

  all_posts = []

  puts "\nCreating 10 posts per user..."
  users.each_with_index do |user, ui|
    categories_for_user = categories.shuffle
    10.times do |pi|
      cat = categories_for_user[pi % categories.size]
      template = post_templates[cat.name].sample
      title = "#{template} #{FFaker::Lorem.word} #{SecureRandom.hex(4)}"

      post = Post.new(user: user, category: cat, title: title, media_type: "image", status: "approved")
      post.media.attach(io: placeholder_io.call, filename: "p_#{user.id}_#{pi}.jpg", content_type: "image/jpeg")
      post.slug = nil # force regeneration
      post.save!
      if post.errors[:slug].any?
        post.slug = "#{title.parameterize}-#{SecureRandom.hex(4)}"
        post.save!
      end
      all_posts << post
    end
  end
  puts "  #{all_posts.size} posts created"

  # ── Votes ─────────────────────────────────────────────────────
  puts "\nCreating votes..."
  vote_count = 0
  all_posts.each do |post|
    upvote_ratio = [0.3, post.user.reputation.to_f / 5000].min + 0.2
    voters = users.reject { |u| u == post.user }
                 .select { rand < upvote_ratio }
                 .sample([rand(2..30), 30].min)

    voters.each do |voter|
      next if Vote.exists?(user_id: voter.id, post_id: post.id)
      Vote.create(user: voter, post: post, upvoted: true)
      vote_count += 1
    end
  end
  puts "  #{vote_count} upvotes created"

  downvote_count = 0
  all_posts.sample(all_posts.size / 7).each do |post|
    voters = users.reject { |u| u == post.user || u.reputation < 100 }
                 .sample(rand(1..4))
    voters.each do |voter|
      next if Vote.exists?(user_id: voter.id, post_id: post.id)
      Vote.create(user: voter, post: post, upvoted: false)
      downvote_count += 1
    end
  end
  puts "  #{downvote_count} downvotes created"

  # ── Comments ──────────────────────────────────────────────────
  puts "\nCreating 20 comments per post..."
  comment_count = 0
  commenters_pool = users.select { |u| u.reputation >= 50 }
  all_posts.each do |post|
    20.times do
      Comment.create!(
        user: commenters_pool.sample,
        post: post,
        body: FFaker::Lorem.sentence[0..200]
      )
      comment_count += 1
    end
  end
  puts "  #{comment_count} comments created"

  # ── Summary ───────────────────────────────────────────────
  puts "\n#{'=' * 50}"
  puts "  Users:       #{User.count}"
  puts "  Posts:       #{Post.count}"
  puts "  Votes:       #{Vote.count}"
  puts "  Comments:    #{Comment.count}"
  puts "  Categories:  #{Category.count}"
  puts "  Thresholds:  #{ReputationThreshold.count}"
  puts "#{'=' * 50}"
  puts "Done! Login with any user: password"
end
