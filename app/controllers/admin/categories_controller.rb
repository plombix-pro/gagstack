class Admin::CategoriesController < ApplicationController
  before_action :require_admin

  def index
    @categories = Category.ordered
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to admin_categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @category = Category.find(params[:id])
  end

  def update
    @category = Category.find(params[:id])
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: "Category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category = Category.find(params[:id])
    @category.destroy!
    redirect_to admin_categories_path, notice: "Category deleted."
  end

  private

  def category_params
    params.require(:category).permit(:name, :slug, :position)
  end
end
