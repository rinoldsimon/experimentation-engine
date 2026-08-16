class AddUniqueIndexToEvents < ActiveRecord::Migration[7.2]
  def up
    # Dedupe first so the new unique index below doesn't fail to apply.
    execute <<~SQL
      DELETE FROM events e
      USING (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY experiment_id, visitor_id, event_type
                 ORDER BY created_at, id
               ) AS row_number
        FROM events
      ) ranked
      WHERE e.id = ranked.id AND ranked.row_number > 1
    SQL

    remove_index :events, name: "index_events_on_experiment_visitor_and_event_type"
    add_index :events, [ :experiment_id, :visitor_id, :event_type ], unique: true,
      name: "index_events_on_experiment_visitor_and_event_type"
  end

  def down
    remove_index :events, name: "index_events_on_experiment_visitor_and_event_type"
    add_index :events, [ :experiment_id, :visitor_id, :event_type ],
      name: "index_events_on_experiment_visitor_and_event_type"
  end
end
