class Admin::ModerationLogsController < ApplicationController
  before_action :require_admin

  def index
    @logs = ModerationLog.order(created_at: :desc).page(params[:page])
  end
end
