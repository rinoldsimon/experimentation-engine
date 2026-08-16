class EnablePgcryptoExtension < ActiveRecord::Migration[7.2]
  def change
    # Provides gen_random_uuid(), used as the default value for all uuid
    # primary keys (see config.generators primary_key_type in application.rb).
    enable_extension "pgcrypto"
  end
end
