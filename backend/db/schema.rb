# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_08_16_184624) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.uuid "variant_id"
    t.string "visitor_id", null: false
    t.string "event_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["experiment_id", "visitor_id", "event_type"], name: "index_events_on_experiment_visitor_and_event_type", unique: true
    t.index ["experiment_id"], name: "index_events_on_experiment_id"
    t.index ["variant_id"], name: "index_events_on_variant_id"
  end

  create_table "experiments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "manual", null: false
    t.index ["name"], name: "index_experiments_on_name", unique: true
  end

  create_table "variants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.string "name", null: false
    t.integer "weight", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "content"
    t.string "content_source", default: "manual", null: false
    t.index ["experiment_id", "name"], name: "index_variants_on_experiment_id_and_name", unique: true
    t.index ["experiment_id"], name: "index_variants_on_experiment_id"
  end

  add_foreign_key "events", "experiments"
  add_foreign_key "events", "variants"
  add_foreign_key "variants", "experiments"
end
