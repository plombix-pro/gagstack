class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.boolean :active, default: true, null: false
      t.bigint :author_id, null: false
      t.timestamps
    end
    add_foreign_key :announcements, :users, column: :author_id
  end
end
