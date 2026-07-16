class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  before_action :redirect_if_signed_in, only: :new
  before_action :require_age_verification, only: :new

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      UserMailer.verification(@user).deliver_later
      redirect_to root_path, notice: "Account created! Check your email to verify your account."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_signed_in
    if Current.user
      redirect_to root_path, alert: "You are already signed in."
      return
    end
  end

  def require_age_verification
    redirect_to new_age_verification_path unless session[:age_verified]
  end

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :username, :date_of_birth)
  end
end
