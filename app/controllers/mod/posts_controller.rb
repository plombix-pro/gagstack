class Mod::PostsController < ApplicationController
  before_action :require_moderator

  def index
    redirect_to mod_root_path
  end

  def update
    @post = Post.find(params[:id])
    @post.update!(status: params[:status])
    ModerationLog.create!(moderator: Current.user, action: "post_#{params[:status]}", target_type: "Post", target_id: @post.id, details: { post_id: @post.id, title: @post.title })

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("mod_post_#{@post.id}") }
    end
  end
end
