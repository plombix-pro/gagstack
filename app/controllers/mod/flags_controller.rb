class Mod::FlagsController < ApplicationController
  before_action :require_moderator

  def index
    @status = params[:status]
    @flags = Flag.order(created_at: :desc)
    @flags = @flags.where(status: @status) if @status.present?
    @flags = @flags.page(params[:page])
  end

  def content
    @flagged_posts = Post.joins(:flags).distinct.page(params[:posts_page])
    @flagged_comments = Comment.joins(:flags).distinct.page(params[:comments_page])
  end

  def update
    @flag = Flag.find(params[:id])
    @flag.update!(status: params[:status])

    case params[:status]
    when "reviewed"
      if @flag.flaggable.is_a?(Post)
        @flag.flaggable.update!(status: :rejected)
        RepCalculator.new(@flag.flaggable.user).apply(:flag_confirmed)
      elsif @flag.flaggable.is_a?(Comment)
        @flag.flaggable.update!(hidden: true)
        RepCalculator.new(@flag.flaggable.user).apply(:flag_confirmed)
      end
    when "dismissed"
      RepCalculator.new(@flag.user).apply(:flag_dismissed)
    end

    ModerationLog.create!(moderator: Current.user, action: "flag_#{params[:status]}", target_type: "Flag", target_id: @flag.id, details: { flag_id: @flag.id })

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@flag) }
    end
  end
end
