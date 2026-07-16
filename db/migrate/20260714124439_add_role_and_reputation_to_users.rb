class AddRoleAndReputationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, default: "user", null: false
    add_column :users, :reputation, :integer, default: 1, null: false
    add_column :users, :banned_at, :datetime
    add_column :users, :flags_count, :integer, default: 0
    add_column :users, :slug, :string
    add_index :users, :slug, unique: true
  end
end
