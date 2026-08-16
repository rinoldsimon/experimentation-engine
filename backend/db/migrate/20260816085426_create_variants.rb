class CreateVariants < ActiveRecord::Migration[7.2]
  def change
    create_table :variants, id: :uuid do |t|
      t.references :experiment, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :weight, null: false, default: 0

      t.timestamps
    end

    add_index :variants, [ :experiment_id, :name ], unique: true
  end
end
