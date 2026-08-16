class RemapExperimentStatusToKillSwitch < ActiveRecord::Migration[7.2]
  def up
    # Old enum was {pending: 0, running: 1, stopped: 2}; backfill to "running".
    execute "UPDATE experiments SET status = 0"
  end

  def down
    execute "UPDATE experiments SET status = 0"
  end
end
