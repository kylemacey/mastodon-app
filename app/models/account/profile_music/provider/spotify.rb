# frozen_string_literal: true

class Account::ProfileMusic::Provider::Spotify
  KEY = 'spotify'
  TRACK_ID_PATTERN = /\A[0-9A-Za-z]{22}\z/
  THUMBNAIL_HOSTS = %w(i.scdn.co).freeze

  class << self
    def handles?(attributes)
      provider_name(attributes) == KEY || spotify_track_id(attributes).present?
    end

    def normalize(attributes, _existing_item = nil)
      track_id = spotify_track_id(attributes)
      return if track_id.blank?

      title = Account::ProfileMusic::Provider.sanitize_text(attributes['title'] || attributes[:title])

      {
        'provider' => KEY,
        'provider_id' => track_id,
        'url' => canonical_url(track_id),
        'embed_url' => embed_url(track_id),
        'title' => title.presence || 'Spotify track',
        'artist' => Account::ProfileMusic::Provider.sanitize_text(attributes['artist'] || attributes[:artist]),
        'thumbnail_url' => Account::ProfileMusic::Provider.valid_https_url?(
          attributes['thumbnail_url'] || attributes[:thumbnail_url],
          allowed_hosts: THUMBNAIL_HOSTS
        ),
      }.compact
    end

    def normalize_stored(attributes)
      normalize(attributes)
    end

    def canonical_url_for(attributes)
      track_id = spotify_track_id(attributes)
      canonical_url(track_id) if track_id
    end

    def from_api(track)
      normalize(
        'provider' => KEY,
        'provider_id' => track['id'],
        'url' => track.dig('external_urls', 'spotify'),
        'title' => track['name'],
        'artist' => Array(track['artists']).pluck('name').join(', '),
        'thumbnail_url' => Array(track.dig('album', 'images')).first&.fetch('url', nil)
      )
    end

    private

    def provider_name(attributes)
      (attributes['provider'] || attributes[:provider]).to_s
    end

    def spotify_track_id(attributes)
      provider_id = (attributes['provider_id'] || attributes[:provider_id] || attributes['id'] || attributes[:id]).to_s
      return provider_id if TRACK_ID_PATTERN.match?(provider_id)

      url = (attributes['url'] || attributes[:url]).to_s.strip
      return Regexp.last_match(1) if url.match(%r{\Aspotify:track:([0-9A-Za-z]{22})\z})

      uri = Addressable::URI.parse(url)
      return unless uri.scheme == 'https' && uri.host == 'open.spotify.com'

      match = uri.path.to_s.match(%r{\A/track/([0-9A-Za-z]{22})/?\z})
      match && match[1]
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def canonical_url(track_id)
      "https://open.spotify.com/track/#{track_id}"
    end

    def embed_url(track_id)
      "https://open.spotify.com/embed/track/#{track_id}"
    end
  end
end
