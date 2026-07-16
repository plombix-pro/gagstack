class CategoriesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  def index
    @categories = Category.ordered
  end

  def show
    @category = Category.find_by!(slug: params[:id])
    redirect_to category_posts_path(@category)
  end
end
