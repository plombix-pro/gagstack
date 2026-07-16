class VerificationsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  def show
    user = User.find_by(verification_token: params[:token])

    if user && user.verification_token.present?
      user.update!(verified_at: Time.current, verification_token: nil)
      start_new_session_for user
      redirect_to root_path, notice: "Email verified! Welcome to GagStack."
    else
      redirect_to root_path, alert: "Invalid or expired verification link."
    end
  end
end
