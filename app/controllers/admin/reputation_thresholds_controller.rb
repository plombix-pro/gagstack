class Admin::ReputationThresholdsController < ApplicationController
  before_action :require_super_admin

  def index
    @thresholds = ReputationThreshold.order(:min_reputation)
  end

  def edit
    @threshold = ReputationThreshold.find(params[:id])
  end

  def update
    @threshold = ReputationThreshold.find(params[:id])
    if @threshold.update(threshold_params)
      redirect_to admin_reputation_thresholds_path, notice: "Threshold updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def threshold_params
    params.require(:reputation_threshold).permit(:min_reputation, :description)
  end
end
