class CreateFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :flags do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.text :reason, null: false
      t.string :status, default: "pending", null: false
      t.timestamps
    end
    add_index :flags, [:status, :created_at]
  end
end
