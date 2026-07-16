class AgeVerificationController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    redirect_to sign_up_path if session[:age_verified]
  end

  def create
    if manual_verified?
      session[:age_verified] = true
      session[:age_verified_at] = Time.current.iso8601
      render json: { status: "ok" }
    else
      render json: { status: "denied" }, status: :forbidden
    end
  end

  private

  def manual_verified?
    return false unless params[:dob].present?

    dob = Date.parse(params[:dob]) rescue nil
    return false unless dob
    return false if dob > Date.current

    dob <= 18.years.ago.to_date
  end
end
