class CommentsController < ApplicationController
  before_action :require_login, only: [:create, :destroy, :vote]
  before_action :require_comment_reputation, only: [:create]
  before_action -> { require_comment_vote_reputation(params[:direction]) }, only: [:vote]
  before_action :set_comment, only: [:destroy, :vote]
  rate_limit to: 30, within: 1.minute, only: %i[ create vote ],
    with: -> { head :too_many_requests }

  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.new(comment_params.merge(user: Current.user))

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post, notice: "Comment added." }
      end
    else
      redirect_to @post, alert: @comment.errors.full_messages.to_sentence
    end
  end

  def destroy
    return head :forbidden unless @comment.user == Current.user || Current.user&.super_admin?
    @post = @comment.post
    @comment.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @post, notice: "Comment deleted." }
    end
  end

  def vote
    return head :unprocessable_entity unless params[:direction].in?(%w[up down])
    return head :forbidden unless Current.user

    direction = params[:direction] == "up"
    vote = @comment.comment_votes.find_or_initialize_by(user: Current.user)

    if vote.upvoted == direction
      vote.destroy
      @comment.decrement!(direction ? :upvotes_count : :downvotes_count)
      result = 0
    else
      @comment.decrement!(:downvotes_count) if vote.persisted? && vote.upvoted == false
      @comment.decrement!(:upvotes_count) if vote.persisted? && vote.upvoted == true
      vote.update!(upvoted: direction)
      @comment.increment!(direction ? :upvotes_count : :downvotes_count)
      result = direction ? 5 : -1
    end

    RepChangeJob.perform_later(user: @comment.user, delta: result) if result != 0

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("comment_#{@comment.id}", partial: "comments/comment", locals: { comment: @comment }) }
    end
  end

  private

  def require_comment_reputation
    require_reputation(:comment) unless Current.user&.moderator? || Current.user&.admin? || Current.user&.super_admin?
  end

  def require_comment_vote_reputation(direction)
    return unless Current.user
    if direction == "down"
      require_reputation(:downvote_comment)
    end
  end

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
