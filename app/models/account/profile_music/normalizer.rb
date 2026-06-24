# frozen_string_literal: true

class Account::ProfileMusic::Normalizer
  Result = Struct.new(:items, :errors, keyword_init: true)

  PROVIDERS = [
    Account::ProfileMusic::Provider::Soundcloud,
    Account::ProfileMusic::Provider::Spotify,
    Account::ProfileMusic::Provider::Bandcamp,
  ].freeze

  class << self
    def normalize_stored(items)
      Array(items).filter_map do |item|
        attributes = coerce_hash(item)
        provider = provider_for(attributes)

        provider&.normalize_stored(attributes)
      end
    end

    def coerce_hash(item)
      return item.to_unsafe_h if item.respond_to?(:to_unsafe_h)
      return item.to_h if item.respond_to?(:to_h)

      { 'url' => item.to_s }
    end

    def provider_for(attributes)
      PROVIDERS.find { |provider| provider.handles?(attributes) }
    end
  end

  def initialize(items, existing_items: [])
    @items = items
    @existing_items = self.class.normalize_stored(existing_items)
  end

  def call
    normalized_items = []
    errors = []

    coerce_array(@items).filter_map do |item|
      attributes = self.class.coerce_hash(item)
      blank_item?(attributes) ? nil : attributes
    end.first(Account::PROFILE_MUSIC_LIMIT).each do |attributes|
      provider = self.class.provider_for(attributes)
      unless provider
        errors << unsupported_provider_error
        next
      end

      normalized = provider.normalize(attributes, existing_item_for(provider, attributes))
      if normalized
        normalized_items << normalized
      else
        errors << invalid_track_error
      end
    rescue Account::ProfileMusic::Provider::Error
      errors << invalid_track_error
    end

    Result.new(items: normalized_items, errors: errors)
  end

  private

  def coerce_array(value)
    return value.values if value.is_a?(Hash)

    Array(value)
  end

  def blank_item?(attributes)
    %i(provider provider_id id url title artist thumbnail_url).all? do |key|
      attributes[key].blank? && attributes[key.to_s].blank?
    end
  end

  def unsupported_provider_error
    I18n.t('profile_music.errors.unsupported_provider', default: 'contains an unsupported music link')
  end

  def invalid_track_error
    I18n.t('profile_music.errors.invalid_track', default: 'contains a music link that could not be resolved')
  end

  def existing_item_for(provider, attributes)
    canonical_url = provider.canonical_url_for(attributes)
    @existing_items.find do |item|
      item['provider'] == provider::KEY && item['url'] == canonical_url
    end
  end
end
