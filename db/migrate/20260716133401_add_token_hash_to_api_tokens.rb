class AddTokenHashToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :token_hash, :string
    add_index :api_tokens, :token_hash, unique: true
  end
end
