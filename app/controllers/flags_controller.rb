class FlagsController < ApplicationController
  before_action :require_login
  before_action -> { require_reputation(:flag_content) }, only: [:create]
  rate_limit to: 20, within: 1.minute, only: [:create],
    with: -> { redirect_back fallback_location: root_path, alert: "Slow down — too many flags." }

  def create
    if params[:post_id]
      @flaggable = Post.find(params[:post_id])
    elsif flaggable_class
      @flaggable = flaggable_class.find(params[:flag][:flaggable_id])
    end

    unless @flaggable
      redirect_back fallback_location: root_path, alert: "Invalid flag target"
      return
    end

    @flag = Current.user.flags.new(flag_params.merge(flaggable: @flaggable))

    if @flag.save
      redirect_back fallback_location: root_path, notice: "Flagged for review."
    else
      redirect_back fallback_location: root_path, alert: @flag.errors.full_messages.to_sentence
    end
  end

  private

  def flag_params
    params.require(:flag).permit(:reason)
  end

  FLAGGABLE_TYPES = {
    "Post" => Post,
    "Comment" => Comment
  }.freeze

  def flaggable_class
    FLAGGABLE_TYPES[params[:flag][:flaggable_type]]
  end
end
