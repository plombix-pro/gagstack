class Admin::DashboardController < ApplicationController
  before_action :require_admin

  def index
    @user_count = User.count
    @post_count = Post.count
    @pending_count = Post.pending_review.count
    @flag_count = Flag.pending.count
    @recent_logs = ModerationLog.order(created_at: :desc).limit(10)
  end
end
