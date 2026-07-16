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
    ModerationLog.create!(moderator: Current.user, action: "admin_user_update", target_type: "User", target_id: @user.id, details: { changes: @user.previous_changes })
    redirect_to admin_users_path, notice: "User updated."
  end

  private

  def user_params
    allowed = %w[user moderator admin]
    role = params.dig(:user, :role)
    return {} unless role.in?(allowed)
    params.require(:user).permit(:reputation).merge(role: role)
  end
end
