class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :media_type, null: false
      t.references :category, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.float :hotness, default: 0.0
      t.float :trending_score, default: 0.0
      t.string :perceptual_hash
      t.string :status, default: "pending", null: false
      t.integer :upvotes_count, default: 0
      t.integer :downvotes_count, default: 0
      t.integer :comments_count, default: 0
      t.integer :views_count, default: 0
      t.timestamps
    end
    add_index :posts, :slug, unique: true
    add_index :posts, [:category_id, :hotness]
    add_index :posts, [:category_id, :created_at]
    add_index :posts, [:status, :category_id]
    add_index :posts, :perceptual_hash
  end
end
