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

    if changing_email?
      change_email(@user, params[:user][:email_address])
      @user.save!
      return redirect_to edit_profile_path, notice: "Verification email sent to #{params[:user][:email_address]}."
    end

    if changing_username?
      unless @user.can?(:change_username)
        return redirect_to edit_profile_path, alert: "You need 500 reputation to change your username."
      end
      @user.username = params[:user][:username]
      @user.slug = params[:user][:username].parameterize
    end

    if params[:user][:password].present?
      @user.password = params[:user][:password]
      @user.password_confirmation = params[:user][:password_confirmation]
    end

    @user.avatar.attach(params[:user][:avatar]) if params[:user][:avatar].present?

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

  def require_password_for_changes
    return unless sensitive_change?

    unless Current.user.authenticate(params[:user][:current_password])
      redirect_to edit_profile_path, alert: "Current password is required to make changes."
    end
  end

  def sensitive_change?
    username = params[:user]&.[](:username)
    email = params[:user]&.[](:email_address)
    password = params[:user]&.[](:password)
    return false unless username.present? || email.present? || password.present?

    email.blank? || email != Current.user.email_address || username.present? || password.present?
  end

  def changing_email?
    params[:user][:email_address].present? && params[:user][:email_address] != @user.email_address
  end

  def changing_username?
    params[:user][:username].present? && params[:user][:username] != @user.username
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
