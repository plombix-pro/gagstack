class CreateModerationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :moderation_logs do |t|
      t.references :moderator, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :target_type
      t.integer :target_id
      t.jsonb :details, default: {}
      t.timestamps
    end
    add_index :moderation_logs, [:target_type, :target_id]
  end
end
