class Post < ApplicationRecord
  belongs_to :user
  belongs_to :category, counter_cache: true
  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :flags, as: :flaggable, dependent: :destroy
  has_one_attached :media
  has_one_attached :thumbnail

  enum :media_type, { image: "image", gif: "gif" }
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }

  attribute :status, default: "approved"

  validates :title, presence: true, length: { maximum: 200 }
  validates :slug, presence: true, uniqueness: true
  validates :media_type, presence: true
  validate :media_must_be_attached, on: :create

  before_validation :generate_slug, on: :create
  after_create_commit :check_reputation_threshold

  scope :approved, -> { where(status: :approved) }
  scope :pending_review, -> { where(status: :pending) }
  scope :fresh, -> { approved.order(created_at: :desc) }
  scope :hot, -> { approved.order(hotness: :desc) }
  scope :search_by_title, ->(query) { where("title ILIKE ?", "%#{query}%") }

  def user_vote(user)
    votes.find_by(user: user)&.upvoted
  end

  def previous_post
    Post.approved.where("id < ?", id).order(id: :desc).first
  end

  def next_post
    Post.approved.where("id > ?", id).order(id: :asc).first
  end

  private

  def media_must_be_attached
    errors.add(:media, "must be attached") unless media.attached?
  end

  def generate_slug
    self.slug = title.parameterize
  end

  def check_reputation_threshold
    update(status: :pending) if user.posts.approved.count < 5
  end
end
