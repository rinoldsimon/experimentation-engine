class AddSourceToExperiments < ActiveRecord::Migration[7.2]
  def change
    # Distinguishes experiments created via the "Draft with AI" flow from
    # manually/seeded ones -- purely a display/UX flag (e.g. only AI-drafted
    # experiments get a Dashboard "Delete" button), not a security boundary.
    add_column :experiments, :source, :string, default: "manual", null: false
  end
end
