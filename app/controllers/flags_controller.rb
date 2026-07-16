class FlagsController < ApplicationController
  before_action :require_login
  before_action -> { require_reputation(:flag_content) }, only: [:create]

  def create
    if params[:post_id]
      @flaggable = Post.find(params[:post_id])
    else
      @flaggable = flaggable_class.find(params[:flag][:flaggable_id])
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

  def flaggable_class
    params[:flag][:flaggable_type].constantize
  rescue NameError
    redirect_back fallback_location: root_path, alert: "Invalid flaggable type"
    nil
  end
end
