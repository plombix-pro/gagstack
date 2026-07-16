categories = [
  { name: "Funny", slug: "funny", position: 1 },
  { name: "Gaming", slug: "gaming", position: 2 },
  { name: "Awesome", slug: "awesome", position: 3 },
  { name: "Cute", slug: "cute", position: 4 },
  { name: "Wholesome", slug: "wholesome", position: 5 },
  { name: "NSFW", slug: "nsfw", position: 6 },
]

categories.each { |c| Category.find_or_create_by!(slug: c[:slug]) { |cat| cat.assign_attributes(c) } }

thresholds = [
  { name: "view_upvote", min_reputation: 1, description: "View and upvote content" },
  { name: "post_images", min_reputation: 10, description: "Post images and GIFs" },
  { name: "flag_content", min_reputation: 15, description: "Flag content for moderation" },
  { name: "comment", min_reputation: 50, description: "Comment on any post" },
  { name: "downvote", min_reputation: 100, description: "Downvote posts" },
  { name: "downvote_comment", min_reputation: 250, description: "Downvote comments" },
  { name: "moderate", min_reputation: 500, description: "Access moderation tools" },
  { name: "appeal_flags", min_reputation: 1000, description: "Appeal flag decisions" },
  { name: "edit_posts", min_reputation: 3000, description: "Edit anyone's posts" },
  { name: "change_username", min_reputation: 500, description: "Change your username" },
  { name: "vote_to_ban", min_reputation: 10000, description: "Vote to ban users" },
]
thresholds.each { |t| ReputationThreshold.find_or_create_by!(name: t[:name]) { |rt| rt.assign_attributes(t) } }

puts "Seeded #{Category.count} categories and #{ReputationThreshold.count} thresholds"
