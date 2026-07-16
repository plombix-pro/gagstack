class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def require_login
    redirect_to sign_in_path, alert: "Please sign in first." unless Current.user
  end

  def require_reputation(privilege)
    return unless Current.user
    unless Current.user.can?(privilege)
      redirect_back fallback_location: root_path, alert: "Your reputation is too low to #{privilege.to_s.tr('_', ' ')}."
    end
  end

  def require_moderator
    redirect_to root_path, alert: "Access denied" unless Current.user&.reputation.to_i >= 500 || Current.user&.moderator? || Current.user&.admin? || Current.user&.super_admin?
  end

  def require_admin
    redirect_to root_path, alert: "Access denied" unless Current.user&.admin? || Current.user&.super_admin?
  end

  def require_super_admin
    redirect_to root_path, alert: "Access denied" unless Current.user&.super_admin?
  end
end
