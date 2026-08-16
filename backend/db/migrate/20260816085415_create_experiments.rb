class CreateExperiments < ActiveRecord::Migration[7.2]
  def change
    create_table :experiments, id: :uuid do |t|
      t.string :name, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :experiments, :name, unique: true
  end
end
