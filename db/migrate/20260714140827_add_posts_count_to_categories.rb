class AddPostsCountToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :posts_count, :integer, default: 0, null: false
  end
end
