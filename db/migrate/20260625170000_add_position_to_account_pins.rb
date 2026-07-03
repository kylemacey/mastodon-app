# frozen_string_literal: true

class AddPositionToAccountPins < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :account_pins, :position, :integer

    safety_assured do
      execute <<~SQL.squish
        WITH ranked_account_pins AS (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY created_at ASC, id ASC) AS position
          FROM account_pins
        )
        UPDATE account_pins
        SET position = ranked_account_pins.position
        FROM ranked_account_pins
        WHERE account_pins.id = ranked_account_pins.id
      SQL

      change_column_null :account_pins, :position, false
    end

    add_index :account_pins, [:account_id, :position], unique: true, algorithm: :concurrently
  end

  def down
    remove_index :account_pins, [:account_id, :position], algorithm: :concurrently
    remove_column :account_pins, :position
  end
end
