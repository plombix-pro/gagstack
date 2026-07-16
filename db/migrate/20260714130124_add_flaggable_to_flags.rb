class AddFlaggableToFlags < ActiveRecord::Migration[8.1]
  def change
    add_column :flags, :flaggable_type, :string
    add_column :flags, :flaggable_id, :bigint
    add_index :flags, [:flaggable_type, :flaggable_id]

    up_only do
      Flag.update_all(flaggable_type: "Post", flaggable_id: :post_id)
    end

    change_column_null :flags, :post_id, true
  end
end
