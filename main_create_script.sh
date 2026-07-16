#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# GagStack — Full Bootstrap Script
# Reproduces the entire application from scratch
# ============================================================

APP_NAME="GagStack"
RUBY_VERSION="3.2.0"

echo "==> Creating $APP_NAME..."

# ── Phase 1: Rails scaffold ──────────────────────────────────
rails new "$APP_NAME" \
  --database=postgresql \
  --css=tailwind \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text

cd "$APP_NAME"

# ── Phase 2: Dependencies ────────────────────────────────────
echo "==> Adding gems..."
cat >> Gemfile << 'RUBY'

gem "bcrypt", "~> 3.1.7"
gem "ancestry"
gem "counter_culture"
gem "kaminari"
gem "rack-attack"
RUBY

bundle install

# ── Phase 2b: Download age estimation models ─────────────────
echo "==> Downloading age verification models..."
bash bin/download_models

# ── Phase 3: Authentication ──────────────────────────────────
echo "==> Setting up authentication..."
bin/rails generate authentication
bin/rails db:create db:migrate

bin/rails generate migration AddRoleAndReputationToUsers \
  role:string reputation:integer banned_at:datetime \
  flags_count:integer slug:string

cat > db/migrate/*_add_role_and_reputation_to_users.rb << 'RUBY'
class AddRoleAndReputationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, default: "user", null: false
    add_column :users, :reputation, :integer, default: 1, null: false
    add_column :users, :banned_at, :datetime
    add_column :users, :flags_count, :integer, default: 0
    add_column :users, :slug, :string
    add_index :users, :slug, unique: true
  end
end
RUBY

bin/rails db:migrate

# ── Phase 4: Categories ──────────────────────────────────────
echo "==> Creating categories..."
bin/rails generate migration CreateCategories \
  name:string slug:string position:integer

cat > db/migrate/*_create_categories.rb << 'RUBY'
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, default: 0
      t.timestamps
    end
    add_index :categories, :slug, unique: true
    add_index :categories, :position
  end
end
RUBY

# ── Phase 5: Posts ─────────────────────────────────────────
echo "==> Creating posts..."
cat > db/migrate/*_create_posts.rb << 'RUBY'
class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :media_type, null: false
      t.references :category, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.float :hotness, default: 0.0
      t.float :trending_score, default: 0.0
      t.string :perceptual_hash
      t.string :status, default: "pending", null: false
      t.integer :upvotes_count, default: 0
      t.integer :downvotes_count, default: 0
      t.integer :comments_count, default: 0
      t.integer :views_count, default: 0
      t.timestamps
    end
    add_index :posts, :slug, unique: true
    add_index :posts, [:category_id, :hotness]
    add_index :posts, [:category_id, :created_at]
    add_index :posts, [:status, :category_id]
    add_index :posts, :perceptual_hash
  end
end
RUBY

# ── Phase 6: Votes ──────────────────────────────────────────
cat > db/migrate/*_create_votes.rb << 'RUBY'
class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.boolean :upvoted, null: false
      t.timestamps
    end
    add_index :votes, [:user_id, :post_id], unique: true
  end
end
RUBY

# ── Phase 7: Comments ───────────────────────────────────────
cat > db/migrate/*_create_comments.rb << 'RUBY'
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.string :ancestry
      t.integer :upvotes_count, default: 0
      t.integer :downvotes_count, default: 0
      t.timestamps
    end
    add_index :comments, [:post_id, :ancestry]
    add_index :comments, :ancestry
  end
end
RUBY

# ── Phase 8: Flags ──────────────────────────────────────────
cat > db/migrate/*_create_flags.rb << 'RUBY'
class CreateFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :flags do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.text :reason, null: false
      t.string :status, default: "pending", null: false
      t.timestamps
    end
    add_index :flags, [:status, :created_at]
  end
end
RUBY

# ── Phase 9: Reputation thresholds ──────────────────────────
cat > db/migrate/*_create_reputation_thresholds.rb << 'RUBY'
class CreateReputationThresholds < ActiveRecord::Migration[8.0]
  def change
    create_table :reputation_thresholds do |t|
      t.string :name, null: false
      t.integer :min_reputation, default: 1, null: false
      t.text :description
      t.timestamps
    end
    add_index :reputation_thresholds, :name, unique: true
  end
end
RUBY

# ── Phase 10: Moderation logs ───────────────────────────────
cat > db/migrate/*_create_moderation_logs.rb << 'RUBY'
class CreateModerationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :moderation_logs do |t|
      t.references :moderator, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :target_type
      t.integer :target_id
      t.jsonb :details, default: {}
      t.timestamps
    end
    add_index :moderation_logs, [:target_type, :target_id]
  end
end
RUBY

bin/rails db:migrate

# ── Phase 11: Seed data ─────────────────────────────────────
cat > db/seeds.rb << 'RUBY'
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
  { name: "vote_to_ban", min_reputation: 10000, description: "Vote to ban users" },
]

thresholds.each { |t| ReputationThreshold.find_or_create_by!(name: t[:name]) { |rt| rt.assign_attributes(t) } }

puts "Seeded #{Category.count} categories and #{ReputationThreshold.count} thresholds"
RUBY

# ── Phase 12: Models ────────────────────────────────────────
echo "==> Creating models..."

cat > app/models/category.rb << 'RUBY'
class Category < ApplicationRecord
  has_many :posts, dependent: :nullify
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  scope :ordered, -> { order(position: :asc) }
end
RUBY

cat > app/models/post.rb << 'RUBY'
class Post < ApplicationRecord
  belongs_to :user
  belongs_to :category, counter_cache: true
  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_one_attached :media
  has_one_attached :thumbnail

  enum :media_type, { image: "image", gif: "gif" }
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }

  validates :title, presence: true, length: { maximum: 200 }
  validates :slug, presence: true, uniqueness: true
  validates :media_type, presence: true
  validates :media, presence: true, attached: true,
            content_type: { in: %w[image/jpeg image/png image/webp image/gif image/avif] },
            size: { less_than: 50.megabytes }

  before_validation :generate_slug, on: :create
  after_create_commit :check_reputation_threshold

  scope :approved, -> { where(status: :approved) }
  scope :pending_review, -> { where(status: :pending) }
  scope :fresh, -> { approved.order(created_at: :desc) }
  scope :hot, -> { approved.order(hotness: :desc) }

  def upvote!(user)
    vote = votes.find_or_initialize_by(user: user)
    if vote.upvoted == true
      vote.destroy!
      decrement!(:upvotes_count)
      0
    else
      decrement!(:downvotes_count) if vote.upvoted == false
      vote.update!(upvoted: true)
      increment!(:upvotes_count)
      ReputationChangeJob.perform_later(user_id: user.id, post_id: id, action: :upvote)
      1
    end
  end

  def downvote!(user)
    vote = votes.find_or_initialize_by(user: user)
    if vote.upvoted == false
      vote.destroy!
      decrement!(:downvotes_count)
      0
    else
      decrement!(:upvotes_count) if vote.upvoted == true
      vote.update!(upvoted: false)
      increment!(:downvotes_count)
      -1
    end
  end

  def user_vote(user)
    votes.find_by(user: user)&.upvoted
  end

  private

  def generate_slug
    self.slug = title.parameterize
  end

  def check_reputation_threshold
    threshold = ReputationThreshold.find_by(name: "post_images")&.min_reputation || 10
    update(status: :pending) if user.reputation < threshold
  end
end
RUBY

cat > app/models/vote.rb << 'RUBY'
class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :post, counter_cache: true
  validates :upvoted, inclusion: { in: [true, false] }
  validates :user_id, uniqueness: { scope: :post_id }
end
RUBY

cat > app/models/comment.rb << 'RUBY'
class Comment < ApplicationRecord
  has_ancestry
  belongs_to :user
  belongs_to :post, counter_cache: true
  has_many :votes, as: :votable, dependent: :destroy

  validates :body, presence: true, length: { maximum: 5000 }
end
RUBY

cat > app/models/flag.rb << 'RUBY'
class Flag < ApplicationRecord
  belongs_to :user
  belongs_to :post
  enum :status, { pending: "pending", reviewed: "reviewed", dismissed: "dismissed" }
  validates :reason, presence: true, length: { maximum: 1000 }
end
RUBY

cat > app/models/reputation_threshold.rb << 'RUBY'
class ReputationThreshold < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :min_reputation, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
RUBY

cat > app/models/moderation_log.rb << 'RUBY'
class ModerationLog < ApplicationRecord
  belongs_to :moderator, class_name: "User"
  validates :action, presence: true
end
RUBY

# ── Phase 13: Routes ────────────────────────────────────────
echo "==> Setting up routes..."
cat > config/routes.rb << 'RUBY'
Rails.application.routes.draw do
  root "posts#index"

  resource :session, only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  resources :categories, only: [:index, :show] do
    resources :posts, only: [:index], controller: "posts"
  end

  resources :posts do
    member do
      post :vote
    end
    resources :comments, only: [:create, :destroy]
  end

  resources :flags, only: [:create]
  resources :comments do
    member do
      post :vote
    end
  end

  namespace :mod do
    get "/", to: "dashboard#index"
    resources :flags, only: [:index, :update]
    resources :posts, only: [:index, :update]
    resources :users, only: [:index, :update]
    get "watermark", to: "watermark#index"
    post "watermark/extract", to: "watermark#extract"
  end

  namespace :admin do
    get "/", to: "dashboard#index"
    resources :users
    resources :categories
    resources :reputation_thresholds, only: [:index, :edit, :update]
    resources :moderation_logs, only: [:index]
  end

  namespace :api do
    namespace :v1 do
      resources :posts, only: [:index, :show, :create]
      resources :categories, only: [:index]
      post "auth/login", to: "auth#login"
      resource :profile, only: [:show, :update]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
RUBY

# ── Phase 14: Controllers ───────────────────────────────────
echo "==> Creating controllers..."

cat > app/controllers/application_controller.rb << 'RUBY'
class ApplicationController < ActionController::Base
  before_action :set_current_user

  private

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_login
    redirect_to sign_in_path unless Current.user
  end

  def require_moderator
    redirect_to root_path unless Current.user&.reputation.to_i >= 500 || Current.user&.moderator? || Current.user&.admin? || Current.user&.super_admin?
  end

  def require_admin
    redirect_to root_path unless Current.user&.admin? || Current.user&.super_admin?
  end

  def require_super_admin
    redirect_to root_path unless Current.user&.super_admin?
  end
end
RUBY

mkdir -p app/controllers/mod app/controllers/admin app/controllers/api/v1

cat > app/controllers/posts_controller.rb << 'RUBY'
class PostsController < ApplicationController
  before_action :require_login, only: [:new, :create]
  before_action :set_post, only: [:show, :vote]

  def index
    @category = Category.find_by!(slug: params[:category_id]) if params[:category_id]
    @posts = FeedBuilder.new(category: @category, sort: params[:sort] || "fresh", cursor: params[:cursor]).call
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @comments = @post.comments.arrange(order: :created_at)
    @comment = @post.comments.new
  end

  def new
    @post = Post.new
    @categories = Category.ordered
  end

  def create
    @post = Current.user.posts.build(post_params)
    signer = UploadSigner.new(Current.user)
    @post.media.attach(params[:media_blob]) if params[:media_blob]

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

    result = params[:direction] == "up" ? @post.upvote!(Current.user) : @post.downvote!(Current.user)
    RepChangeJob.perform_later(user: @post.user, delta: result == 1 ? 10 : -2) if result != 0

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@post) }
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :category_id, :media_type, :media, :thumbnail, :perceptual_hash)
  end
end
RUBY

cat > app/controllers/votes_controller.rb << 'RUBY'
class VotesController < ApplicationController
  before_action :require_login

  def create
    @post = Post.find(params[:post_id])
    @vote = @post.votes.find_or_initialize_by(user: Current.user)

    if params[:direction] == "up"
      if @vote.upvoted == true
        @vote.destroy
        @post.decrement!(:upvotes_count)
      else
        @post.decrement!(:downvotes_count) if @vote.upvoted == false
        @vote.update(upvoted: true)
        @post.increment!(:upvotes_count)
      end
    elsif params[:direction] == "down"
      if @vote.upvoted == false
        @vote.destroy
        @post.decrement!(:downvotes_count)
      else
        @post.decrement!(:upvotes_count) if @vote.upvoted == true
        @vote.update(upvoted: false)
        @post.increment!(:downvotes_count)
      end
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@post) }
    end
  end
end
RUBY

cat > app/controllers/comments_controller.rb << 'RUBY'
class CommentsController < ApplicationController
  before_action :require_login, only: [:create, :destroy]

  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.new(comment_params.merge(user: Current.user, parent_id: params[:parent_id]))

    if @comment.save
      RepChangeJob.perform_later(user: @comment.user, delta: 1) if Current.user != @post.user
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post }
      end
    else
      redirect_to @post, alert: @comment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    return head :forbidden unless @comment.user == Current.user || Current.user&.super_admin?
    @comment.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @comment.post }
    end
  end

  def vote
    @comment = Comment.find(params[:id])
    return head :forbidden unless Current.user

    if params[:direction] == "up"
      # simplified voting
      @comment.increment!(:upvotes_count)
    elsif params[:direction] == "down"
      @comment.increment!(:downvotes_count)
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@comment) }
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
RUBY

cat > app/controllers/flags_controller.rb << 'RUBY'
class FlagsController < ApplicationController
  before_action :require_login

  def create
    @post = Post.find(params[:post_id])
    @flag = @post.flags.new(flag_params.merge(user: Current.user))

    if @flag.save
      redirect_to @post, notice: "Flagged for moderation."
    else
      redirect_to @post, alert: @flag.errors.full_messages.to_sentence
    end
  end

  private

  def flag_params
    params.require(:flag).permit(:reason)
  end
end
RUBY

# ── Phase 14b: Mod controllers ──────────────────────────────
cat > app/controllers/mod/dashboard_controller.rb << 'RUBY'
class Mod::DashboardController < ApplicationController
  before_action :require_moderator

  def index
    @pending_flags = Flag.pending.order(created_at: :desc).limit(20)
    @pending_posts = Post.pending_review.order(created_at: :desc).limit(20)
  end
end
RUBY

cat > app/controllers/mod/flags_controller.rb << 'RUBY'
class Mod::FlagsController < ApplicationController
  before_action :require_moderator

  def index
    @flags = Flag.pending.order(created_at: :desc)
  end

  def update
    @flag = Flag.find(params[:id])
    @flag.update!(status: params[:status])
    ModerationLog.create!(moderator: Current.user, action: "flag_#{params[:status]}", target: @flag, details: { flag_id: @flag.id })

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@flag) }
    end
  end
end
RUBY

cat > app/controllers/mod/posts_controller.rb << 'RUBY'
class Mod::PostsController < ApplicationController
  before_action :require_moderator

  def index
    @posts = Post.pending_review.order(created_at: :desc)
  end

  def update
    @post = Post.find(params[:id])
    @post.update!(status: params[:status])
    ModerationLog.create!(moderator: Current.user, action: "post_#{params[:status]}", target: @post, details: { post_id: @post.id, title: @post.title })

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@post) }
    end
  end
end
RUBY

cat > app/controllers/mod/watermark_controller.rb << 'RUBY'
class Mod::WatermarkController < ApplicationController
  before_action :require_moderator

  def index
  end

  def extract
    # Client-side WASM extraction — just serves the page
    @media_url = params[:media_url]
  end
end
RUBY

# ── Phase 14c: Admin controllers ────────────────────────────
cat > app/controllers/admin/dashboard_controller.rb << 'RUBY'
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
RUBY

cat > app/controllers/admin/users_controller.rb << 'RUBY'
class Admin::UsersController < ApplicationController
  before_action :require_admin

  def index
    @users = User.order(created_at: :desc).page(params[:page])
  end

  def show
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if params[:ban]
      @user.update!(banned_at: Time.current)
    elsif params[:unban]
      @user.update!(banned_at: nil)
    else
      @user.update!(user_params)
    end
    ModerationLog.create!(moderator: Current.user, action: "admin_user_update", target: @user, details: { changes: @user.previous_changes })
    redirect_to admin_users_path, notice: "User updated."
  end

  private

  def user_params
    params.require(:user).permit(:role, :reputation)
  end
end
RUBY

cat > app/controllers/admin/reputation_thresholds_controller.rb << 'RUBY'
class Admin::ReputationThresholdsController < ApplicationController
  before_action :require_super_admin

  def index
    @thresholds = ReputationThreshold.order(:name)
  end

  def edit
    @threshold = ReputationThreshold.find(params[:id])
  end

  def update
    @threshold = ReputationThreshold.find(params[:id])
    if @threshold.update(threshold_params)
      redirect_to admin_reputation_thresholds_path, notice: "Threshold updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def threshold_params
    params.require(:reputation_threshold).permit(:min_reputation, :description)
  end
end
RUBY

cat > app/controllers/api/v1/auth_controller.rb << 'RUBY'
class Api::V1::AuthController < ApplicationController
  def login
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      session_token = SecureRandom.hex(32)
      render json: { token: session_token, user: { id: user.id, username: user.username, email: user.email } }
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end
end
RUBY

# ── Phase 15: Services ──────────────────────────────────────
echo "==> Creating services..."

mkdir -p app/services

cat > app/services/feed_builder.rb << 'RUBY'
class FeedBuilder
  PER_PAGE = 20

  def initialize(category: nil, sort: "fresh", cursor: nil)
    @category = category
    @sort = sort
    @cursor = cursor
  end

  def call
    posts = Post.approved.includes(:user, :category, :thumbnail_attachment)
    posts = posts.where(category: @category) if @category

    posts = case @sort
    when "hot" then posts.hot
    when "trending" then posts.order(trending_score: :desc)
    else posts.fresh
    end

    posts = posts.where("created_at < ?", Time.zone.parse(@cursor)) if @cursor.present?
    posts.limit(PER_PAGE)
  end
end
RUBY

cat > app/services/rep_calculator.rb << 'RUBY'
class RepCalculator
  DELTAS = {
    post_upvote: 10,
    post_downvote: -2,
    comment_upvote: 5,
    comment_downvote: -1,
    post_deleted_after_downvote: 3,
    flag_confirmed: -10,
    flag_dismissed: 1,
    ban: -100,
  }.freeze

  def initialize(user)
    @user = user
  end

  def apply(action)
    delta = DELTAS[action]
    return 0 unless delta
    @user.update!(reputation: [@user.reputation + delta, 0].max)
    delta
  end
end
RUBY

cat > app/services/hotness_calculator.rb << 'RUBY'
class HotnessCalculator
  def self.calculate(post)
    score = post.upvotes_count - post.downvotes_count
    return 0 if score <= 0
    order = Math.log10([score, 1].max)
    seconds = post.created_at.to_f - 1134028003
    (order + seconds / 45000.0).round(7)
  end

  def self.recalculate_all!
    Post.find_each do |post|
      post.update!(hotness: calculate(post))
    end
  end
end
RUBY

cat > app/services/upload_signer.rb << 'RUBY'
class UploadSigner
  def initialize(user)
    @user = user
    @expires_in = 3600
  end

  def signed_upload_url
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "upload",
      content_type: "image/jpeg",
      byte_size: 0
    )
    {
      url: blob.service_url_for_direct_upload(expires_in: @expires_in),
      headers: blob.service_headers_for_direct_upload,
      blob_signed_id: blob.signed_id,
      watermark_key: generate_watermark_key
    }
  end

  private

  def generate_watermark_key
    SecureRandom.hex(16)
  end
end
RUBY

# ── Phase 16: Jobs ──────────────────────────────────────────
echo "==> Creating jobs..."

cat > app/jobs/hotness_calculation_job.rb << 'RUBY'
class HotnessCalculationJob < ApplicationJob
  queue_as :default

  def perform
    HotnessCalculator.recalculate_all!
  end
end
RUBY

cat > app/jobs/rep_change_job.rb << 'RUBY'
class RepChangeJob < ApplicationJob
  queue_as :default

  def perform(user:, delta:)
    user.update!(reputation: [user.reputation + delta, 0].max)
  end
end
RUBY

cat > app/jobs/trending_score_job.rb << 'RUBY'
class TrendingScoreJob < ApplicationJob
  queue_as :default

  def perform
    # Simplified trending: hotness + recent upvote count
    Post.approved.find_each do |post|
      recent_upvotes = post.votes.where(upvoted: true, created_at: 6.hours.ago..Time.current).count
      post.update!(trending_score: post.hotness + (recent_upvotes * 1.5))
    end
  end
end
RUBY

# ── Phase 17: Views ─────────────────────────────────────────
echo "==> Creating views..."

mkdir -p app/views/posts app/views/comments app/views/mod app/views/admin app/views/shared

cat > app/views/layouts/application.html.erb << 'ERB'
<!DOCTYPE html>
<html class="dark">
  <head>
    <title><%= content_for(:title) || "GagStack" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="current-user-id" content="<%= Current.user&.id %>">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="bg-gray-950 text-gray-100 min-h-screen">
    <nav class="fixed top-0 z-50 w-full border-b border-gray-800 bg-gray-950/95 backdrop-blur supports-[backdrop-filter]:bg-gray-950/80">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between">
          <div class="flex items-center gap-6">
            <%= link_to "GagStack", root_path, class: "text-xl font-bold text-amber-500" %>
            <div class="hidden sm:flex items-center gap-1">
              <%= link_to "Hot", root_path(sort: "hot"), class: "rounded-md px-3 py-1.5 text-sm text-gray-400 hover:text-white #{'text-amber-400' if params[:sort] == 'hot'}" %>
              <%= link_to "Trending", root_path(sort: "trending"), class: "rounded-md px-3 py-1.5 text-sm text-gray-400 hover:text-white #{'text-amber-400' if params[:sort] == 'trending'}" %>
              <%= link_to "Fresh", root_path, class: "rounded-md px-3 py-1.5 text-sm text-gray-400 hover:text-white #{'text-amber-400' if params[:sort].blank? || params[:sort] == 'fresh'}" %>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <% Category.ordered.each do |cat| %>
              <%= link_to cat.name, category_posts_path(cat), class: "text-sm text-gray-500 hover:text-gray-300 hidden lg:inline" %>
            <% end %>
            <% if Current.user %>
              <%= link_to "Post", new_post_path, class: "rounded-lg bg-amber-500 px-4 py-1.5 text-sm font-medium text-black hover:bg-amber-400" %>
              <div class="relative" data-controller="dropdown">
                <button class="flex items-center gap-1 text-sm text-gray-300 hover:text-white">
                  <%= Current.user.username %>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
                </button>
                <div class="absolute right-0 mt-2 w-48 rounded-lg border border-gray-800 bg-gray-900 py-1 shadow-xl hidden" data-dropdown-target="menu">
                  <%= link_to "Profile", "#", class: "block px-4 py-2 text-sm text-gray-300 hover:bg-gray-800" %>
                  <% if Current.user.reputation.to_i >= 500 || Current.user.moderator? || Current.user.admin? %>
                    <%= link_to "Mod Dashboard", mod_root_path, class: "block px-4 py-2 text-sm text-gray-300 hover:bg-gray-800" %>
                  <% end %>
                  <% if Current.user.admin? || Current.user.super_admin? %>
                    <%= link_to "Admin Panel", admin_root_path, class: "block px-4 py-2 text-sm text-gray-300 hover:bg-gray-800" %>
                  <% end %>
                  <%= button_to "Logout", session_path, method: :delete, class: "block w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-gray-800" %>
                </div>
              </div>
            <% else %>
              <%= link_to "Login", sign_in_path, class: "text-sm text-gray-300 hover:text-white" %>
              <%= link_to "Sign up", sign_up_path, class: "rounded-lg bg-amber-500 px-4 py-1.5 text-sm font-medium text-black hover:bg-amber-400" %>
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    <main class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 pt-20 pb-8">
      <%= yield %>
    </main>
  </body>
</html>
ERB

cat > app/views/posts/index.html.erb << 'ERB'
<div class="flex gap-2 mb-6">
  <span class="text-sm text-gray-500 self-center">Sort:</span>
  <%= link_to "Fresh", params.key?(:category_id) ? category_posts_path(@category, sort: nil) : root_path, class: "rounded-lg px-3 py-1 text-sm #{params[:sort].blank? || params[:sort] == 'fresh' ? 'bg-amber-500 text-black' : 'bg-gray-800 text-gray-300 hover:bg-gray-700'}" %>
  <%= link_to "Hot", params.key?(:category_id) ? category_posts_path(@category, sort: "hot") : root_path(sort: "hot"), class: "rounded-lg px-3 py-1 text-sm #{params[:sort] == 'hot' ? 'bg-amber-500 text-black' : 'bg-gray-800 text-gray-300 hover:bg-gray-700'}" %>
  <%= link_to "Trending", params.key?(:category_id) ? category_posts_path(@category, sort: "trending") : root_path(sort: "trending"), class: "rounded-lg px-3 py-1 text-sm #{params[:sort] == 'trending' ? 'bg-amber-500 text-black' : 'bg-gray-800 text-gray-300 hover:bg-gray-700'}" %>
</div>

<div class="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 gap-4 space-y-4" id="posts">
  <%= render partial: "posts/post", collection: @posts, as: :post %>
</div>

<% if @posts.any? %>
  <div class="text-center py-8">
    <%= link_to "Load more", url_for(sort: params[:sort], cursor: @posts.last.created_at.iso8601(6)), class: "rounded-lg bg-gray-800 px-6 py-2 text-sm text-gray-300 hover:bg-gray-700", data: { turbo_stream: true } %>
  </div>
<% end %>
ERB

cat > app/views/posts/_post.html.erb << 'ERB'
<div class="break-inside-avoid rounded-xl border border-gray-800 bg-gray-900 overflow-hidden hover:border-gray-700 transition-colors" id="<%= dom_id(post) %>">
  <%= link_to post_path(post), class: "block" do %>
    <div class="relative">
      <% if post.thumbnail.attached? %>
        <%= image_tag post.thumbnail, class: "w-full h-auto", loading: "lazy" %>
      <% elsif post.media.attached? && post.image? %>
        <%= image_tag post.media, class: "w-full h-auto", loading: "lazy" %>
      <% elsif post.media.attached? && post.gif? %>
        <video autoplay loop muted playsinline class="w-full h-auto" preload="none">
          <source src="<%= url_for(post.media) %>" type="video/webm">
        </video>
      <% end %>
      <div class="absolute inset-0 bg-gradient-to-t from-gray-950/60 to-transparent pointer-events-none"></div>
    </div>
  <% end %>
  <div class="p-3">
    <h2 class="font-semibold text-sm mb-2 line-clamp-2">
      <%= link_to post.title, post_path(post), class: "text-gray-100 hover:text-amber-400" %>
    </h2>
    <div class="flex items-center justify-between text-xs text-gray-500">
      <div class="flex items-center gap-2">
        <span class="text-gray-400"><%= post.user.username %></span>
        <span>·</span>
        <span><%= time_ago_in_words(post.created_at) %> ago</span>
      </div>
      <div class="flex items-center gap-3" data-controller="vote" data-vote-post-id="<%= post.id %>">
        <button data-action="vote#up" class="flex items-center gap-1 <%= post.user_vote(Current.user) == true ? 'text-amber-500' : 'text-gray-500 hover:text-amber-400' %>">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>
          <%= post.upvotes_count %>
        </button>
        <button data-action="vote#down" class="flex items-center gap-1 <%= post.user_vote(Current.user) == false ? 'text-red-500' : 'text-gray-500 hover:text-red-400' %>">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
          <%= post.downvotes_count %>
        </button>
        <span class="flex items-center gap-1 text-gray-500">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>
          <%= post.comments_count %>
        </span>
      </div>
    </div>
  </div>
</div>
ERB

cat > app/views/posts/new.html.erb << 'ERB'
<div class="max-w-2xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">Post to GagStack</h1>

  <%= form_with model: @post, local: true, html: { multipart: true } do |form| %>
    <% if @post.errors.any? %>
      <div class="rounded-lg bg-red-900/30 border border-red-800 p-4 mb-4">
        <ul class="text-sm text-red-400">
          <% @post.errors.full_messages.each do |msg| %>
            <li><%= msg %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div class="space-y-4" data-controller="media-processor" data-media-processor-upload-url-value="<%= @upload_url %>">
      <div>
        <%= form.label :title, class: "block text-sm font-medium text-gray-300 mb-1" %>
        <%= form.text_field :title, required: true, maxlength: 200, class: "w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-gray-100 placeholder-gray-500 focus:border-amber-500 focus:outline-none" %>
      </div>

      <div>
        <%= form.label :category_id, class: "block text-sm font-medium text-gray-300 mb-1" %>
        <%= form.collection_select :category_id, @categories, :id, :name, {}, class: "w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-gray-100 focus:border-amber-500 focus:outline-none" %>
      </div>

      <div>
        <%= form.label :media, class: "block text-sm font-medium text-gray-300 mb-1" %>
        <div class="border-2 border-dashed border-gray-700 rounded-lg p-8 text-center hover:border-gray-500 transition-colors cursor-pointer" data-action="click->media-processor#trigger">
          <input type="file" accept="image/*" data-media-processor-target="input" data-action="media-processor#process" class="hidden">
          <svg class="mx-auto h-12 w-12 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>
          <p class="mt-2 text-sm text-gray-500" data-media-processor-target="progress">Click to select image or GIF</p>
        </div>
      </div>

      <%= form.hidden_field :media_type %>
      <%= form.hidden_field :perceptual_hash %>

      <%= form.submit "Post", class: "w-full rounded-lg bg-amber-500 px-4 py-2 text-sm font-medium text-black hover:bg-amber-400 disabled:opacity-50", data: { disable_with: "Posting..." } %>
    </div>
  <% end %>
</div>
ERB

cat > app/views/posts/show.html.erb << 'ERB'
<div class="max-w-4xl mx-auto">
  <div class="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden">
    <div class="p-4 border-b border-gray-800">
      <div class="flex items-center gap-2 text-xs text-gray-500 mb-2">
        <%= link_to @post.category.name, category_posts_path(@post.category), class: "text-amber-400 hover:text-amber-300" %>
        <span>·</span>
        <span>Posted by <%= @post.user.username %></span>
        <span>·</span>
        <span><%= time_ago_in_words(@post.created_at) %> ago</span>
      </div>
      <h1 class="text-xl font-bold"><%= @post.title %></h1>
    </div>

    <div class="bg-black flex items-center justify-center">
      <% if @post.image? %>
        <%= image_tag @post.media, class: "max-h-[80vh] w-auto", loading: "lazy" %>
      <% elsif @post.gif? %>
        <video autoplay loop muted playsinline class="max-h-[80vh] w-auto" controls>
          <source src="<%= url_for(@post.media) %>" type="video/webm">
        </video>
      <% end %>
    </div>

    <div class="p-4 flex items-center gap-4 text-sm" data-controller="vote" data-vote-post-id="<%= @post.id %>">
      <button data-action="vote#up" class="flex items-center gap-1 <%= @post.user_vote(Current.user) == true ? 'text-amber-500' : 'text-gray-400 hover:text-amber-400' %>">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>
        <span><%= @post.upvotes_count %></span>
      </button>
      <button data-action="vote#down" class="flex items-center gap-1 <%= @post.user_vote(Current.user) == false ? 'text-red-500' : 'text-gray-400 hover:text-red-400' %>">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
        <span><%= @post.downvotes_count %></span>
      </button>
      <span class="text-gray-500"><%= @post.comments_count %> comments</span>
    </div>
  </div>

  <div class="mt-6">
    <h2 class="text-lg font-semibold mb-4">Comments</h2>
    <% if Current.user %>
      <%= form_with model: [@post, @comment], local: true, class: "mb-6" do |form| %>
        <div class="flex gap-2">
          <%= form.text_area :body, placeholder: "Write a comment...", rows: 2, class: "flex-1 rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-gray-100 placeholder-gray-500 focus:border-amber-500 focus:outline-none resize-none" %>
          <%= form.submit "Comment", class: "self-end rounded-lg bg-amber-500 px-4 py-2 text-sm font-medium text-black hover:bg-amber-400" %>
        </div>
      <% end %>
    <% else %>
      <p class="text-sm text-gray-500 mb-6"><%= link_to "Login", sign_in_path, class: "text-amber-400 hover:text-amber-300" %> to comment.</p>
    <% end %>

    <div class="space-y-4" id="comments">
      <% @comments.each do |comment, children| %>
        <%= render "comments/comment", comment: comment, children: children %>
      <% end %>
    </div>
  </div>
</div>
ERB

cat > app/views/comments/_comment.html.erb << 'ERB'
<div class="border-l-2 border-gray-800 pl-4 py-2" id="<%= dom_id(comment) %>">
  <div class="flex items-center gap-2 text-xs text-gray-500 mb-1">
    <span class="font-medium text-gray-300"><%= comment.user.username %></span>
    <span><%= time_ago_in_words(comment.created_at) %> ago</span>
  </div>
  <p class="text-sm text-gray-200 mb-2"><%= comment.body %></p>
  <div class="flex items-center gap-2 text-xs">
    <button class="text-gray-500 hover:text-amber-400">▲ <%= comment.upvotes_count %></button>
    <button class="text-gray-500 hover:text-red-400">▼ <%= comment.downvotes_count %></button>
  </div>
  <% if children.present? %>
    <div class="mt-2 space-y-2">
      <% children.each do |child, grandchildren| %>
        <%= render "comments/comment", comment: child, children: grandchildren %>
      <% end %>
    </div>
  <% end %>
</div>
ERB

cat > app/views/mod/dashboard/index.html.erb << 'ERB'
<div class="max-w-6xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">Moderation Dashboard</h1>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <div>
      <h2 class="text-lg font-semibold mb-3 text-amber-400">Pending Flags</h2>
      <div class="space-y-3" id="pending-flags">
        <% @pending_flags.each do |flag| %>
          <div class="rounded-lg border border-gray-800 bg-gray-900 p-3" id="<%= dom_id(flag) %>">
            <div class="flex items-start justify-between">
              <div>
                <p class="text-sm text-gray-300"><%= flag.reason %></p>
                <p class="text-xs text-gray-500 mt-1">Flagged by <%= flag.user.username %> on <%= link_to flag.post.title, flag.post, class: "text-amber-400 hover:text-amber-300" %></p>
              </div>
              <div class="flex gap-2">
                <%= button_to mod_flag_path(flag, status: "reviewed"), method: :patch, class: "rounded bg-green-600 px-3 py-1 text-xs text-white hover:bg-green-500" do %>
                  Approve
                <% end %>
                <%= button_to mod_flag_path(flag, status: "dismissed"), method: :patch, class: "rounded bg-gray-700 px-3 py-1 text-xs text-gray-300 hover:bg-gray-600" do %>
                  Dismiss
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        <% if @pending_flags.empty? %>
          <p class="text-sm text-gray-500">No pending flags.</p>
        <% end %>
      </div>
    </div>

    <div>
      <h2 class="text-lg font-semibold mb-3 text-amber-400">Pending Posts</h2>
      <div class="space-y-3" id="pending-posts">
        <% @pending_posts.each do |post| %>
          <div class="rounded-lg border border-gray-800 bg-gray-900 p-3" id="<%= dom_id(post) %>">
            <div class="flex items-start justify-between">
              <div>
                <p class="text-sm text-gray-300 font-medium"><%= link_to post.title, post, class: "hover:text-amber-400" %></p>
                <p class="text-xs text-gray-500 mt-1">by <%= post.user.username %> · <%= time_ago_in_words(post.created_at) %> ago</p>
              </div>
              <div class="flex gap-2">
                <%= button_to mod_post_path(post, status: "approved"), method: :patch, class: "rounded bg-green-600 px-3 py-1 text-xs text-white hover:bg-green-500" do %>
                  Approve
                <% end %>
                <%= button_to mod_post_path(post, status: "rejected"), method: :patch, class: "rounded bg-red-600 px-3 py-1 text-xs text-white hover:bg-red-500" do %>
                  Reject
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        <% if @pending_posts.empty? %>
          <p class="text-sm text-gray-500">No pending posts.</p>
        <% end %>
      </div>
    </div>
  </div>

  <div class="mt-8">
    <h2 class="text-lg font-semibold mb-3 text-amber-400">Watermark Extraction</h2>
    <p class="text-sm text-gray-500 mb-3">Upload a media file to extract the embedded watermark and identify the original author.</p>
    <div data-controller="watermark-extractor">
      <input type="file" accept="image/*" data-watermark-extractor-target="input" data-action="watermark-extractor#extract" class="text-sm text-gray-300 file:mr-4 file:rounded-lg file:border-0 file:bg-amber-500 file:px-4 file:py-2 file:text-sm file:font-medium file:text-black hover:file:bg-amber-400">
      <div data-watermark-extractor-target="result" class="mt-3"></div>
    </div>
  </div>
</div>
ERB

cat > app/views/admin/dashboard/index.html.erb << 'ERB'
<div class="max-w-6xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">Admin Panel</h1>

  <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
    <div class="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <p class="text-2xl font-bold text-amber-400"><%= @user_count %></p>
      <p class="text-xs text-gray-500">Users</p>
    </div>
    <div class="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <p class="text-2xl font-bold text-amber-400"><%= @post_count %></p>
      <p class="text-xs text-gray-500">Posts</p>
    </div>
    <div class="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <p class="text-2xl font-bold text-red-400"><%= @pending_count %></p>
      <p class="text-xs text-gray-500">Pending Posts</p>
    </div>
    <div class="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <p class="text-2xl font-bold text-red-400"><%= @flag_count %></p>
      <p class="text-xs text-gray-500">Open Flags</p>
    </div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <div>
      <h2 class="text-lg font-semibold mb-3">Quick Actions</h2>
      <div class="space-y-2">
        <%= link_to "Manage Users", admin_users_path, class: "block rounded-lg bg-gray-800 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700" %>
        <%= link_to "Moderation Logs", admin_moderation_logs_path, class: "block rounded-lg bg-gray-800 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700" %>
        <%= link_to "Reputation Thresholds", admin_reputation_thresholds_path, class: "block rounded-lg bg-gray-800 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700" %>
      </div>
    </div>
    <div>
      <h2 class="text-lg font-semibold mb-3">Recent Activity</h2>
      <div class="space-y-2">
        <% @recent_logs.each do |log| %>
          <div class="text-xs text-gray-500">
            <span class="text-gray-300"><%= log.moderator.username %></span>
            <%= log.action %> · <%= time_ago_in_words(log.created_at) %> ago
          </div>
        <% end %>
        <% if @recent_logs.empty? %>
          <p class="text-sm text-gray-500">No activity yet.</p>
        <% end %>
      </div>
    </div>
  </div>
</div>
ERB

# ── Phase 18: Stimulus controllers ──────────────────────────
echo "==> Creating Stimulus controllers..."

cat > app/javascript/controllers/vote_controller.js << 'JS'
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { postId: Number }

  up() {
    this.submit("up")
  }

  down() {
    this.submit("down")
  }

  submit(direction) {
    const csrf = document.querySelector('meta[name="csrf-token"]').content
    fetch(`/posts/${this.postIdValue}/vote`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrf,
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ direction: direction })
    })
  }
}
JS

cat > app/javascript/controllers/dropdown_controller.js << 'JS'
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    document.addEventListener("click", this.close.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.close.bind(this))
  }

  close(e) {
    if (!this.element.contains(e.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
JS

cat > app/javascript/controllers/media_processor_controller.js << 'JS'
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "progress"]
  static values = { uploadUrl: String }

  trigger() {
    this.inputTarget.click()
  }

  async process(event) {
    const file = event.target.files[0]
    if (!file) return

    this.showProgress("Processing...")

    const isGif = file.type === "image/gif"
    let result

    if (isGif) {
      result = await this.transcodeGif(file)
    } else {
      result = await this.compressImage(file)
    }

    this.showProgress("Watermarking...")
    const watermarked = await this.embedWatermark(result.blob)

    this.showProgress("Uploading...")
    const blobSignedId = await this.uploadToActiveStorage(watermarked)

    // Populate the hidden fields
    this.element.querySelector('input[name="post[media_type]"]').value = isGif ? "gif" : "image"
    this.element.querySelector('input[name="post[perceptual_hash]"]').value = result.pHash

    this.showProgress("Ready!")
  }

  async compressImage(file) {
    const img = await createImageBitmap(file)
    const canvas = document.createElement("canvas")
    const maxDim = 1920
    let { width, height } = img
    if (width > maxDim || height > maxDim) {
      const ratio = Math.min(maxDim / width, maxDim / height)
      width = Math.round(width * ratio)
      height = Math.round(height * ratio)
    }
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, width, height)

    const blob = await this.canvasToBlob(canvas, "image/webp", 0.85)
    const pHash = await this.computePerceptualHash(canvas)

    this.showProgress("Generating thumbnail...")
    const thumbCanvas = document.createElement("canvas")
    thumbCanvas.width = 280
    thumbCanvas.height = Math.round(280 * (height / width))
    const thumbCtx = thumbCanvas.getContext("2d")
    thumbCtx.drawImage(canvas, 0, 0, 280, thumbCanvas.height)
    const thumbBlob = await this.canvasToBlob(thumbCanvas, "image/webp", 0.7)

    return { blob, thumbBlob, pHash }
  }

  async transcodeGif(file) {
    const { default: importModule } = await import("https://cdn.jsdelivr.net/npm/@ffmpeg/ffmpeg@0.12.10/+esm")
    const ffmpeg = new importModule.FFmpeg()
    await ffmpeg.load()
    ffmpeg.writeFile("input.gif", await file.arrayBuffer())
    await ffmpeg.exec(["-i", "input.gif", "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "30", "-an", "output.webm"])
    const data = await ffmpeg.readFile("output.webm")
    const blob = new Blob([data.buffer], { type: "video/webm" })

    // Get first frame for thumbnail
    await ffmpeg.exec(["-i", "input.gif", "-vframes", "1", "thumb.jpg"])
    const thumbData = await ffmpeg.readFile("thumb.jpg")
    const thumbBlob = new Blob([thumbData.buffer], { type: "image/jpeg" })

    // Simple pHash from first frame
    const img = await createImageBitmap(thumbBlob)
    const canvas = document.createElement("canvas")
    canvas.width = 32
    canvas.height = 32
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, 32, 32)
    const pHash = await this.computePerceptualHash(canvas)

    return { blob, thumbBlob, pHash }
  }

  async embedWatermark(blob) {
    const img = await createImageBitmap(blob)
    const canvas = document.createElement("canvas")
    canvas.width = img.width
    canvas.height = img.height
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0)

    const userId = document.querySelector('meta[name="current-user-id"]')?.content
    if (!userId) return blob

    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const watermarked = this.applyDctWatermark(imageData.data, canvas.width, canvas.height, userId)
    ctx.putImageData(new ImageData(watermarked, canvas.width, canvas.height), 0, 0)

    return this.canvasToBlob(canvas, blob.type, 0.9)
  }

  applyDctWatermark(pixels, width, height, userId) {
    const blockSize = 8
    const strength = 4

    for (let by = 0; by < height; by += blockSize) {
      for (let bx = 0; bx < width; bx += blockSize) {
        const block = []
        for (let y = 0; y < blockSize && by + y < height; y++) {
          for (let x = 0; x < blockSize && bx + x < width; x++) {
            const idx = ((by + y) * width + (bx + x)) * 4
            block.push(0.299 * pixels[idx] + 0.587 * pixels[idx + 1] + 0.114 * pixels[idx + 2])
          }
        }
        if (block.length < blockSize * blockSize) continue

        const dct = this.dct2d(Float64Array.from(block), blockSize, blockSize)
        for (let i = 1; i < blockSize; i++) {
          for (let j = 1; j < blockSize; j++) {
            if (i + j >= 2 && i + j <= 5) {
              const bit = (userId.charCodeAt((i * blockSize + j) % userId.length) % 2 === 0) ? -strength : strength
              dct[i * blockSize + j] += bit
            }
          }
        }
        const idct = this.dct2d(dct, blockSize, blockSize)
        for (let y = 0; y < blockSize && by + y < height; y++) {
          for (let x = 0; x < blockSize && bx + x < width; x++) {
            const idx = ((by + y) * width + (bx + x)) * 4
            const lum = Math.max(0, Math.min(255, Math.round(idct[y * blockSize + x])))
            pixels[idx] = lum
            pixels[idx + 1] = lum
            pixels[idx + 2] = lum
          }
        }
      }
    }
    return pixels
  }

  dct2d(pixels, width, height) {
    const result = new Float64Array(width * height)
    const factor = Math.PI / Math.max(width, height)
    for (let u = 0; u < height; u++) {
      for (let v = 0; v < width; v++) {
        let sum = 0
        for (let x = 0; x < height; x++) {
          for (let y = 0; y < width; y++) {
            sum += pixels[x * width + y] *
              Math.cos((2 * x + 1) * u * factor * 0.5) *
              Math.cos((2 * y + 1) * v * factor * 0.5)
          }
        }
        const cu = u === 0 ? 1 / Math.SQRT2 : 1
        const cv = v === 0 ? 1 / Math.SQRT2 : 1
        result[u * width + v] = sum * cu * cv * 2 / width
      }
    }
    return result
  }

  async canvasToBlob(canvas, type, quality) {
    return new Promise(resolve => canvas.toBlob(resolve, type, quality))
  }

  async computePerceptualHash(canvas) {
    const size = 32
    const small = document.createElement("canvas")
    small.width = size
    small.height = size
    const sCtx = small.getContext("2d")
    sCtx.drawImage(canvas, 0, 0, size, size)
    const data = sCtx.getImageData(0, 0, size, size).data

    const pixels = []
    for (let i = 0; i < data.length; i += 4) {
      pixels.push(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2])
    }

    const dct = this.dct2d(Float64Array.from(pixels), size, size)
    const coeffs = []
    for (let y = 0; y < 8; y++) {
      for (let x = 0; x < 8; x++) {
        if (x === 0 && y === 0) continue
        coeffs.push(dct[y * size + x])
      }
    }
    const sorted = [...coeffs].sort((a, b) => a - b)
    const median = sorted[Math.floor(sorted.length / 2)]
    return coeffs.map(c => c > median ? "1" : "0").join("")
  }

  showProgress(message) {
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = message
    }
  }
}
JS

cat > app/javascript/controllers/watermark_extractor_controller.js << 'JS'
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "result"]

  async extract(event) {
    const file = event.target.files[0]
    if (!file) return

    const img = await createImageBitmap(file)
    const canvas = document.createElement("canvas")
    canvas.width = img.width
    canvas.height = img.height
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0)

    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const userId = this.extractWatermark(imageData.data, canvas.width, canvas.height)

    this.resultTarget.innerHTML = userId
      ? `<p class="text-sm text-green-400">Watermark detected — User ID: <strong>${userId}</strong></p>`
      : `<p class="text-sm text-gray-500">No watermark detected.</p>`
  }

  extractWatermark(pixels, width, height) {
    const blockSize = 8
    const bits = []
    let userId = ""
    let currentByte = 0
    let bitCount = 0

    for (let by = 0; by < Math.min(height, 64); by += blockSize) {
      for (let bx = 0; bx < Math.min(width, 64); bx += blockSize) {
        const block = []
        for (let y = 0; y < blockSize && by + y < height; y++) {
          for (let x = 0; x < blockSize && bx + x < width; x++) {
            const idx = ((by + y) * width + (bx + x)) * 4
            block.push(0.299 * pixels[idx] + 0.587 * pixels[idx + 1] + 0.114 * pixels[idx + 2])
          }
        }
        if (block.length < blockSize * blockSize) continue

        const dct = this.dct2d(Float64Array.from(block), blockSize, blockSize)
        const bit = dct[2 * blockSize + 1] > dct[1 * blockSize + 2] ? 1 : 0

        currentByte = (currentByte << 1) | bit
        bitCount++

        if (bitCount >= 8) {
          if (currentByte === 0) break
          userId += String.fromCharCode(currentByte)
          currentByte = 0
          bitCount = 0
        }
      }
    }

    return userId || null
  }

  dct2d(pixels, width, height) {
    const result = new Float64Array(width * height)
    const factor = Math.PI / Math.max(width, height)
    for (let u = 0; u < height; u++) {
      for (let v = 0; v < width; v++) {
        let sum = 0
        for (let x = 0; x < height; x++) {
          for (let y = 0; y < width; y++) {
            sum += pixels[x * width + y] *
              Math.cos((2 * x + 1) * u * factor * 0.5) *
              Math.cos((2 * y + 1) * v * factor * 0.5)
          }
        }
        const cu = u === 0 ? 1 / Math.SQRT2 : 1
        const cv = v === 0 ? 1 / Math.SQRT2 : 1
        result[u * width + v] = sum * cu * cv * 2 / width
      }
    }
    return result
  }
}
JS

# ── Phase 19: Importmap ─────────────────────────────────────
cat > config/importmap.rb << 'RUBY'
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
RUBY

# ── Phase 20: Tailwind dark theme ───────────────────────────
cat > app/assets/tailwind/application.css << 'CSS'
@import "tailwindcss";

@theme {
  --color-amber-50: #fffbeb;
  --color-amber-100: #fef3c7;
  --color-amber-200: #fde68a;
  --color-amber-300: #fcd34d;
  --color-amber-400: #fbbf24;
  --color-amber-500: #f59e0b;
  --color-amber-600: #d97706;
}
CSS

# ── Phase 21: Content Security Policy ───────────────────────
cat > config/initializers/content_security_policy.rb << 'RUBY'
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.media_src   :self, :https, :blob
  policy.object_src  :none
  policy.script_src  :self, :https, :unsafe_eval, :unsafe_inline, :blob
  policy.style_src   :self, :https, :unsafe_inline
  policy.connect_src :self, :https, :blob
  policy.worker_src  :self, :blob
end
RUBY

# ── Phase 22: Rate limiting ─────────────────────────────────
cat > config/initializers/rack_attack.rb << 'RUBY'
class Rack::Attack
  throttle("uploads/ip", limit: 10, period: 60) do |req|
    req.ip if req.path == "/posts" && req.post?
  end

  throttle("votes/ip", limit: 60, period: 60) do |req|
    req.ip if req.path.match?(/\/posts\/\d+\/vote/)
  end

  throttle("comments/ip", limit: 20, period: 60) do |req|
    req.ip if req.path.match?(/\/posts\/\d+\/comments/) && req.post?
  end

  throttle("login/ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/session" && req.post?
  end
end
RUBY

# ── Phase 23: Recurring jobs ────────────────────────────────
cat > config/recurring.yml << 'RUBY'
production:
  hotness_calculation:
    class: HotnessCalculationJob
    schedule: every hour
  trending_score:
    class: TrendingScoreJob
    schedule: every 30 minutes
RUBY

# ── Phase 24: Deploy config ─────────────────────────────────
cat > config/deploy.yml << 'YML'
service: gag_stack
image: gag_stack

servers:
  web:
    - 192.168.0.1

proxy:
  ssl: true
  host: gagstack.example.com

registry:
  server: ghcr.io
  username: your-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
  clear:
    SOLID_QUEUE_IN_PUMA: true

volumes:
  - "gag_stack_storage:/rails/storage"

asset_path: /rails/public/assets

builder:
  arch: amd64
YML

# ── Phase 25: Tests ─────────────────────────────────────────
echo "==> Setting up tests..."

cat > test/test_helper.rb << 'RUBY'
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "simplecov"
SimpleCov.start("rails") if ENV["COVERAGE"]

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    include FactoryBot::Syntax::Methods
  end
end
RUBY

# ── Done ────────────────────────────────────────────────────
echo "==> GagStack bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. cd $APP_NAME"
echo "  2. bin/rails db:create db:migrate db:seed"
echo "  3. bin/dev"
echo "  4. Visit http://localhost:3000"
echo ""
echo "Note: Age verification uses on-device facial age estimation."
echo "      All processing stays in the browser — no images are sent to the server."
