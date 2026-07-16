class PostsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  before_action :require_login, only: [:new, :create]
  before_action :require_post_reputation, only: [:create]
  before_action -> { require_vote_reputation(params[:direction]) }, only: [:vote]
  rate_limit to: 20, within: 1.minute, only: %i[ create vote ],
    with: -> { redirect_back fallback_location: root_path, alert: "Slow down — too many requests." }
  before_action :set_post, only: [:show, :vote]

  def index
    @category = Category.find_by!(slug: params[:category_id]) if params[:category_id]
    @posts = FeedBuilder.new(category: @category, sort: params[:sort] || "hot", cursor: params[:cursor]).call
    respond_to do |format|
      format.html
      format.turbo_stream { render formats: :html }
    end
  end

  def show
    @comments = @post.comments.visible.arrange(order: :created_at)
    @comment = @post.comments.new
  end

  def new
    @post = Post.new
    @categories = Category.ordered
  end

  def create
    @post = Current.user.posts.build(post_params)

    if params[:media_signed_id].present?
      attach_uploaded_media(params[:media_signed_id])
    end

    if @post.save
      redirect_to @post, notice: "Posted!"
    else
      @categories = Category.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def vote
    return head :unprocessable_entity unless params[:direction].in?(%w[up down])
    return head :forbidden unless Current.user

    direction = params[:direction] == "up"
    vote = @post.votes.find_or_initialize_by(user: Current.user)

    if vote.upvoted == direction
      vote.destroy
      @post.decrement!(direction ? :upvotes_count : :downvotes_count)
      result = 0
    else
      @post.decrement!(:downvotes_count) if vote.persisted? && vote.upvoted == false
      @post.decrement!(:upvotes_count) if vote.persisted? && vote.upvoted == true
      vote.update!(upvoted: direction)
      @post.increment!(direction ? :upvotes_count : :downvotes_count)
      result = direction ? 10 : -2
    end

    RepChangeJob.perform_later(user: @post.user, delta: result) if result != 0

    respond_to do |format|
      format.json { render json: { upvotes_count: @post.upvotes_count, downvotes_count: @post.downvotes_count, user_vote: @post.user_vote(Current.user) } }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("post_#{@post.id}", partial: "posts/post_card", locals: { post: @post }) }
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def require_post_reputation
    require_reputation(:post_images) unless Current.user&.moderator? || Current.user&.admin? || Current.user&.super_admin?
  end

  def require_vote_reputation(direction)
    return unless Current.user
    if direction == "down"
      require_reputation(:downvote)
    end
  end

  def post_params
    params.require(:post).permit(:title, :category_id, :media_type, :media, :thumbnail, :perceptual_hash)
  end

  def attach_uploaded_media(signed_id)
    blob = ActiveStorage::Blob.find_signed!(signed_id)
    if blob.attachments.exists?
      @post.errors.add(:media, "cannot reuse an already published file")
      return
    end
    @post.media.attach(blob)
  rescue ActiveStorage::Blob::IncorrectDigest
    @post.errors.add(:media, "invalid media upload")
  end
end
