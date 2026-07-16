class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :unconfirmed_email, :string
    add_index :users, :unconfirmed_email
    add_column :users, :email_change_token, :string
    add_index :users, :email_change_token
    add_column :users, :email_change_token_expires_at, :datetime
    add_column :users, :last_email_changed_at, :datetime
  end
end
