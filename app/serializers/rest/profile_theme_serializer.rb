# frozen_string_literal: true

class REST::ProfileThemeSerializer < ActiveModel::Serializer
  include RoutingHelper

  attributes :id, :profile_dom_id, :profile_background, :profile_background_static,
             :profile_background_color, :profile_accent_color, :profile_font,
             :profile_custom_css

  def id
    object.id.to_s
  end

  def profile_dom_id
    object.profile_theme_dom_id
  end

  def profile_background
    object.profile_background_file_name.present? ? full_asset_url(object.profile_background_original_url) : nil
  end

  def profile_background_static
    object.profile_background_file_name.present? ? full_asset_url(object.profile_background_static_url) : nil
  end

  def profile_custom_css
    object.scoped_profile_custom_css
  end
end
