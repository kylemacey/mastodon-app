# frozen_string_literal: true

class AddProfileMusicToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :profile_music, :jsonb, null: false, default: []
  end
end
