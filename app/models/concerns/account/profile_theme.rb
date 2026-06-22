# frozen_string_literal: true

module Account::ProfileTheme
  extend ActiveSupport::Concern

  PROFILE_BACKGROUND_IMAGE_MIME_TYPES = Account::Header::HEADER_IMAGE_MIME_TYPES
  PROFILE_BACKGROUND_LIMIT = 8.megabytes
  PROFILE_BACKGROUND_DIMENSIONS = [1920, 1080].freeze
  PROFILE_BACKGROUND_MAX_PIXELS = PROFILE_BACKGROUND_DIMENSIONS.first * PROFILE_BACKGROUND_DIMENSIONS.last
  PROFILE_FONTS = %w(system sans serif mono pixel).freeze
  PROFILE_CUSTOM_CSS_LIMIT = 10.kilobytes
  PROFILE_THEME_COLOR = UserRole::CSS_COLORS

  class_methods do
    def profile_background_styles(file)
      styles = { original: { pixels: PROFILE_BACKGROUND_MAX_PIXELS, file_geometry_parser: FastGeometryParser } }
      styles[:static] = { format: 'png', convert_options: '-coalesce', file_geometry_parser: FastGeometryParser } if file.content_type == 'image/gif'
      styles
    end

    private :profile_background_styles
  end

  included do
    has_attached_file :profile_background, styles: ->(f) { profile_background_styles(f) }, convert_options: { all: '+profile "!icc,*" +set date:modify +set date:create +set date:timestamp' }, processors: [:lazy_thumbnail]
    validates_attachment_content_type :profile_background, content_type: PROFILE_BACKGROUND_IMAGE_MIME_TYPES
    validates_attachment_size :profile_background, less_than: PROFILE_BACKGROUND_LIMIT

    before_validation :normalize_profile_theme

    validates :profile_background_color, :profile_accent_color, format: { with: PROFILE_THEME_COLOR, allow_blank: true }, if: :local?
    validates :profile_font, inclusion: { in: PROFILE_FONTS }, if: :local?
    validates :profile_custom_css, length: { maximum: PROFILE_CUSTOM_CSS_LIMIT }, if: :local?
  end

  def profile_background_original_url
    profile_background.url(:original)
  end

  def profile_background_static_url
    profile_background_content_type == 'image/gif' ? profile_background.url(:static) : profile_background_original_url
  end

  def profile_theme_dom_id
    "profile_#{profile_theme_dom_slug}"
  end

  def scoped_profile_custom_css
    ProfileCssSanitizer.call(profile_custom_css, "##{profile_theme_dom_id}")
  end

  private

  def normalize_profile_theme
    self.profile_font = 'system' if profile_font.blank?
    self.profile_background_color = normalize_profile_theme_color(profile_background_color)
    self.profile_accent_color = normalize_profile_theme_color(profile_accent_color)
    self.profile_custom_css = profile_custom_css.to_s
  end

  def normalize_profile_theme_color(value)
    value = value.to_s.strip
    return '' if value.blank?

    value = value.delete_prefix('#')
    value = value.chars.flat_map { |char| [char, char] }.join if value.length == 3
    "##{value.upcase}"
  end

  def profile_theme_dom_slug
    profile_theme_dom_source.downcase.gsub('@', '__').gsub(/[^a-z0-9_]+/, '_').gsub(/\A_+|_+\z/, '').presence || id.to_s
  end

  def profile_theme_dom_source
    local? ? "#{username}@#{Rails.configuration.x.local_domain}" : pretty_acct
  end
end
