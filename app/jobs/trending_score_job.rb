class TrendingScoreJob < ApplicationJob
  queue_as :default

  def perform
    Post.approved.find_each do |post|
      recent_upvotes = post.votes.where(upvoted: true, created_at: 6.hours.ago..Time.current).count
      post.update!(trending_score: post.hotness + (recent_upvotes * 1.5))
    end
  end
end
