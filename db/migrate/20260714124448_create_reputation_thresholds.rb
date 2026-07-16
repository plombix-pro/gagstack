class CreateReputationThresholds < ActiveRecord::Migration[8.0]
  def change
    create_table :reputation_thresholds do |t|
      t.string :name, null: false
      t.integer :min_reputation, default: 1, null: false
      t.text :description
      t.timestamps
    end
    add_index :reputation_thresholds, :name, unique: true
  end
end
