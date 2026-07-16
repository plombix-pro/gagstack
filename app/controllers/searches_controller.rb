class SearchesController < ApplicationController
  allow_unauthenticated_access

  def show
    @posts = Post.search_by_title(params[:q]).approved.order(created_at: :desc)
    respond_to do |format|
      format.html
      format.turbo_stream { render formats: :html }
    end
  end
end
