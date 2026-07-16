class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :flags, dependent: :destroy
  has_many :comment_votes, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_one_attached :avatar

  enum :role, { user: "user", moderator: "moderator", admin: "admin", super_admin: "super_admin" }

  validates :email_address, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true, length: { minimum: 2, maximum: 30 }
  validates :date_of_birth, presence: true
  validate :must_be_18_or_older
  validate :email_change_rate_limit, on: :update

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  before_create :set_defaults
  before_create :generate_verification_token

  def verified?
    verified_at.present?
  end

  def banned?
    banned_at.present?
  end

  def can?(privilege)
    threshold = ReputationThreshold.find_by(name: privilege)&.min_reputation || 0
    reputation >= threshold
  end

  def pending_email_change?
    unconfirmed_email.present? && email_change_token.present?
  end

  def confirm_email_change!
    return false unless pending_email_change?
    return false if email_change_token_expires_at&.past?

    update!(
      email_address: unconfirmed_email,
      unconfirmed_email: nil,
      email_change_token: nil,
      email_change_token_expires_at: nil,
      last_email_changed_at: Time.current
    )
  end

  def cancel_email_change!
    update!(
      unconfirmed_email: nil,
      email_change_token: nil,
      email_change_token_expires_at: nil
    )
  end

  private

  def must_be_18_or_older
    return unless date_of_birth
    errors.add(:date_of_birth, "You must be 18 or older to use GagStack") if date_of_birth > 18.years.ago.to_date
  end

  def set_defaults
    self.username = email_address.split("@").first if username.blank?
    self.slug = username.parameterize
    self.reputation ||= 1
  end

  def generate_verification_token
    self.verification_token = SecureRandom.hex(32)
  end

  def email_change_rate_limit
    return unless email_address_changed?
    return unless last_email_changed_at
    return if last_email_changed_at < 7.days.ago

    errors.add(:email_address, "can only be changed once per week")
  end
end
