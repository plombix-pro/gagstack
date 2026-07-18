class CategoriesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  def index
    @categories = Category.ordered
  end

  def show
    @category = Category.find_by!(slug: params[:id])
    redirect_to root_path and return if !authenticated? && @category.name.match?(/nsfw/i)
    redirect_to category_posts_path(@category)
  end
end
