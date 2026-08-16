class RemapExperimentStatusToKillSwitch < ActiveRecord::Migration[7.2]
  def up
    # Old enum was {pending: 0, running: 1, stopped: 2}; new enum is
    # {running: 0, paused: 1}. Backfill any existing rows to "running" so no
    # row is left holding a status integer without a matching label. This is
    # a no-op on a fresh/empty table (e.g. via db:schema:load).
    execute "UPDATE experiments SET status = 0"
  end

  def down
    execute "UPDATE experiments SET status = 0"
  end
end
