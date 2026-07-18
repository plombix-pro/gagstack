class RemoveAncestryFromComments < ActiveRecord::Migration[8.1]
  def change
    remove_index :comments, column: :ancestry, if_exists: true
    remove_index :comments, column: [:post_id, :ancestry], if_exists: true
    remove_column :comments, :ancestry, :string
  end
end
