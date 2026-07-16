class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.string :ancestry
      t.integer :upvotes_count, default: 0
      t.integer :downvotes_count, default: 0
      t.timestamps
    end
    add_index :comments, [:post_id, :ancestry]
    add_index :comments, :ancestry
  end
end
