# frozen_string_literal: true

module Account::ProfileMusic
  extend ActiveSupport::Concern

  ACTIVE_PUBLIC_PROVIDERS = %w(soundcloud).freeze

  included do
    before_validation :normalize_profile_music

    validate :profile_music_must_be_valid, if: :local?
  end

  def profile_music
    Account::ProfileMusic::Normalizer.normalize_stored(self[:profile_music])
  end

  def public_profile_music
    active_music = profile_music.filter do |item|
      ACTIVE_PUBLIC_PROVIDERS.include?(item['provider'])
    end

    active_music.map.with_index do |item, index|
      item.merge('featured' => index.zero?)
    end
  end

  private

  def normalize_profile_music
    result = Account::ProfileMusic::Normalizer.new(
      self[:profile_music],
      existing_items: attribute_in_database(:profile_music)
    ).call

    self[:profile_music] = result.items
    @profile_music_errors = result.errors
  end

  def profile_music_must_be_valid
    Array(@profile_music_errors).each do |message|
      errors.add(:profile_music, message)
    end
  end
end
