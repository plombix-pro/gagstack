class Admin::AnnouncementsController < ApplicationController
  before_action :require_admin

  def index
    @announcements = Announcement.order(created_at: :desc)
  end

  def new
    @announcement = Announcement.new
  end

  def create
    @announcement = Announcement.new(announcement_params)
    @announcement.author = Current.user
    if @announcement.save
      redirect_to admin_announcements_path, notice: "Announcement created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @announcement = Announcement.find(params[:id])
  end

  def update
    @announcement = Announcement.find(params[:id])
    if @announcement.update(announcement_params)
      redirect_to admin_announcements_path, notice: "Announcement updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @announcement = Announcement.find(params[:id])
    @announcement.destroy!
    redirect_to admin_announcements_path, notice: "Announcement deleted."
  end

  private

  def announcement_params
    params.require(:announcement).permit(:active, :content)
  end
end
