class AgeVerificationController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    redirect_to sign_up_path if session[:age_verified]
  end

  def create
    if ai_verified? || manual_verified?
      session[:age_verified] = true
      session[:age_verified_at] = Time.current.iso8601
      render json: { status: "ok" }
    else
      render json: { status: "denied" }, status: :forbidden
    end
  end

  private

  def ai_verified?
    params[:method] == "ai" && params[:estimated_age].to_i >= 18
  end

  def manual_verified?
    return false unless params[:method] == "manual" && params[:dob].present?

    dob = Date.parse(params[:dob]) rescue nil
    return false unless dob

    dob <= 18.years.ago.to_date
  end
end
