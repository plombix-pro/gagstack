class Mod::WatermarkController < ApplicationController
  before_action :require_moderator

  def index
    redirect_to mod_root_path
  end

  def extract
    @media_url = params[:media_url]
  end
end
