class EmailChangesController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  def show
    user = User.find_by(email_change_token: params[:token])

    if user && user.confirm_email_change!
      start_new_session_for user
      redirect_to edit_profile_path, notice: "Email address confirmed."
    else
      redirect_to edit_profile_path, alert: "Invalid or expired email change link."
    end
  end
end
