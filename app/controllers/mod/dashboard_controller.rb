class Mod::DashboardController < ApplicationController
  before_action :require_moderator

  def index
    @pending_flags = Flag.pending.order(created_at: :desc).limit(20)
    @pending_posts = Post.pending_review.order(created_at: :desc).limit(20)
  end
end
