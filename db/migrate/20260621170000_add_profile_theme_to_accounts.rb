# frozen_string_literal: true

class AddProfileThemeToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :profile_background_file_name, :string
    add_column :accounts, :profile_background_content_type, :string
    add_column :accounts, :profile_background_file_size, :integer
    add_column :accounts, :profile_background_updated_at, :datetime
    add_column :accounts, :profile_background_storage_schema_version, :integer

    add_column :accounts, :profile_background_color, :string, null: false, default: ''
    add_column :accounts, :profile_accent_color, :string, null: false, default: ''
    add_column :accounts, :profile_font, :string, null: false, default: 'system'
    add_column :accounts, :profile_custom_css, :text, null: false, default: ''
  end
end
