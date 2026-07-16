class Admin::FlagsController < ApplicationController
  before_action :require_admin

  def index
    @status = params[:status]
    @flags = Flag.order(created_at: :desc)
    @flags = @flags.where(status: @status) if @status.present?
    @flags = @flags.page(params[:page])
  end

  def content
    @flagged_posts = Post.joins(:flags).distinct.page(params[:posts_page])
    @flagged_comments = Comment.joins(:flags).distinct.page(params[:comments_page])
  end
end
