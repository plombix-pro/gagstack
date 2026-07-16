class ProfilesController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :require_password_for_changes, only: :update

  def show
    @user = User.find_by!(slug: params[:username])
    @posts = @user.posts.approved.order(created_at: :desc)
    @upvoted_posts = Post.joins(:votes).where(votes: { user: @user, upvoted: true }).approved.order(created_at: :desc)
    @downvoted_posts = Post.joins(:votes).where(votes: { user: @user, upvoted: false }).approved.order(created_at: :desc)
    @commented_posts = Post.joins(:comments).where(comments: { user_id: @user.id }).approved.distinct.order(created_at: :desc)
    @thresholds = ReputationThreshold.order(:min_reputation)
    @earned = @thresholds.select { |t| @user.can?(t.name) }
    @next = @thresholds.detect { |t| !@user.can?(t.name) }
  end

  def edit
    @user = Current.user
    @thresholds = ReputationThreshold.order(:min_reputation)
    @earned = @thresholds.select { |t| @user.can?(t.name) }
  end

  def update
    @user = Current.user
    attributes = profile_params

    if changing_email?
      change_email(@user, attributes[:email_address])
      @user.save!
      return redirect_to edit_profile_path, notice: "Verification email sent to #{attributes[:email_address]}."
    end

    if changing_username?
      unless @user.can?(:change_username)
        return redirect_to edit_profile_path, alert: "You need 500 reputation to change your username."
      end
      @user.username = attributes[:username]
      @user.slug = attributes[:username].parameterize
    end

    if attributes[:password].present?
      @user.password = attributes[:password]
      @user.password_confirmation = attributes[:password_confirmation]
    end

    @user.avatar.attach(attributes[:avatar]) if attributes[:avatar].present?

    if @user.save
      redirect_to edit_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def cancel_email_change
    Current.user.cancel_email_change!
    redirect_to edit_profile_path, notice: "Email change cancelled."
  end

  private

  def profile_params
    params.fetch(:user, {}).permit(:email_address, :username, :password, :password_confirmation, :avatar, :current_password)
  end

  def require_password_for_changes
    return unless sensitive_change?

    unless Current.user.authenticate(profile_params[:current_password])
      redirect_to edit_profile_path, alert: "Current password is required to make changes."
      return
    end
  end

  def sensitive_change?
    attrs = profile_params
    username = attrs[:username]
    email = attrs[:email_address]
    password = attrs[:password]
    return false unless username.present? || email.present? || password.present?

    email.blank? || email != Current.user.email_address || username.present? || password.present?
  end

  def changing_email?
    email = profile_params[:email_address]
    email.present? && email != @user.email_address
  end

  def changing_username?
    username = profile_params[:username]
    username.present? && username != @user.username
  end

  def change_email(user, new_email)
    user.update!(
      unconfirmed_email: new_email,
      email_change_token: SecureRandom.hex(32),
      email_change_token_expires_at: 7.days.from_now
    )
    UserMailer.email_change(user).deliver_later
  end
end
