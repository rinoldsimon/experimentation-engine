class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events, id: :uuid do |t|
      t.references :experiment, null: false, foreign_key: true, type: :uuid
      t.references :variant, null: true, foreign_key: true, type: :uuid
      t.string :visitor_id, null: false
      t.string :event_type, null: false

      t.timestamps
    end

    add_index :events, [ :experiment_id, :visitor_id, :event_type ],
      name: "index_events_on_experiment_visitor_and_event_type"
  end
end
