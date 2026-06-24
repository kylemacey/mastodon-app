# frozen_string_literal: true

class Account::ProfileMusic::Provider::Soundcloud
  KEY = 'soundcloud'
  OEMBED_URL = 'https://soundcloud.com/oembed'
  TRACK_URL_PATTERN = %r{\A/[^/]+/[^/]+/?\z}
  THUMBNAIL_HOSTS = %w(.sndcdn.com).freeze

  class << self
    def handles?(attributes)
      provider_name(attributes) == KEY || soundcloud_track_url?(attributes['url'] || attributes[:url])
    end

    def normalize(attributes, existing_item = nil)
      api_item = from_api(attributes)
      return api_item if metadata_complete?(api_item)

      url = canonical_url_for(attributes) || api_item&.fetch('url', nil)
      return if url.blank?

      resolved_item = resolve_with_api(url, api_item&.fetch('provider_id', nil))
      return resolved_item if resolved_item.present?

      return api_item if api_item.present?

      return existing_item.merge('url' => url, 'embed_url' => embed_url(existing_item['provider_id'])) if reusable_existing_item?(existing_item)

      resolve(url)
    end

    def normalize_stored(attributes)
      track_id = soundcloud_track_id(attributes)
      url = canonical_url_for(attributes)
      return if track_id.blank? || url.blank?

      {
        'provider' => KEY,
        'provider_id' => track_id,
        'url' => url,
        'embed_url' => embed_url(track_id),
        'title' => Account::ProfileMusic::Provider.sanitize_text(attributes['title']).presence || 'SoundCloud track',
        'artist' => Account::ProfileMusic::Provider.sanitize_text(attributes['artist']),
        'thumbnail_url' => Account::ProfileMusic::Provider.valid_https_url?(
          attributes['thumbnail_url'],
          allowed_hosts: THUMBNAIL_HOSTS
        ),
      }.compact
    end

    def canonical_url_for(attributes)
      url = (attributes['url'] || attributes[:url] || attributes['permalink_url'] || attributes[:permalink_url]).to_s.strip
      uri = Addressable::URI.parse(url)
      return unless uri.scheme == 'https' && soundcloud_host?(uri.host) && TRACK_URL_PATTERN.match?(uri.path.to_s)

      uri.query = nil
      uri.fragment = nil
      uri.to_s.delete_suffix('/')
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def from_api(track)
      track_id = soundcloud_track_id(track)
      url = canonical_url_for(track)
      return if track_id.blank? || url.blank?
      return if track_access(track).present? && track_access(track) != 'playable'

      {
        'provider' => KEY,
        'provider_id' => track_id,
        'url' => url,
        'embed_url' => embed_url(track_id),
        'title' => Account::ProfileMusic::Provider.sanitize_text(track['title'] || track[:title]).presence || 'SoundCloud track',
        'artist' => Account::ProfileMusic::Provider.sanitize_text(
          track.dig('user', 'username') ||
            track.dig(:user, :username) ||
            track['artist'] ||
            track[:artist]
        ),
        'thumbnail_url' => Account::ProfileMusic::Provider.valid_https_url?(
          track['artwork_url'] ||
            track[:artwork_url] ||
            track.dig('user', 'avatar_url') ||
            track.dig(:user, :avatar_url) ||
            track['thumbnail_url'] ||
            track[:thumbnail_url],
          allowed_hosts: THUMBNAIL_HOSTS
        ),
      }.compact
    end

    private

    def provider_name(attributes)
      (attributes['provider'] || attributes[:provider]).to_s
    end

    def soundcloud_track_id(attributes)
      (attributes['provider_id'] || attributes[:provider_id] || attributes['id'] || attributes[:id]).to_s.presence
    end

    def track_access(attributes)
      (attributes['access'] || attributes[:access]).to_s.presence
    end

    def soundcloud_track_url?(url)
      canonical_url_for('url' => url).present?
    end

    def soundcloud_host?(host)
      %w(soundcloud.com www.soundcloud.com).include?(host)
    end

    def reusable_existing_item?(item)
      item.present? && item['provider_id'].present?
    end

    def metadata_complete?(item)
      item.present? && item['artist'].present? && item['thumbnail_url'].present?
    end

    def resolve_with_api(url, track_id = nil)
      service = ProfileMusic::SoundcloudSearchService.new

      item = if track_id.present?
               service.find_track(track_id)
             else
               service.resolve_url(url)
             end

      raise Account::ProfileMusic::Provider::Error if item.blank?

      item
    rescue ProfileMusic::SoundcloudSearchService::MissingConfigurationError,
           ProfileMusic::SoundcloudSearchService::UnexpectedResponseError
      nil
    end

    def resolve(url)
      body = Request.new(:get, "#{OEMBED_URL}?#{Rack::Utils.build_query(format: 'json', url: url)}")
        .add_headers('Accept' => 'application/json')
        .perform do |response|
        raise Account::ProfileMusic::Provider::Error unless response.code == 200

        response.body_with_limit
      end

      data = JSON.parse(body)
      track_id = extract_track_id(data['html'])
      raise Account::ProfileMusic::Provider::Error if track_id.blank?

      {
        'provider' => KEY,
        'provider_id' => track_id,
        'url' => url,
        'embed_url' => embed_url(track_id),
        'title' => title(data),
        'artist' => Account::ProfileMusic::Provider.sanitize_text(data['author_name']),
        'thumbnail_url' => Account::ProfileMusic::Provider.valid_https_url?(
          data['thumbnail_url'],
          allowed_hosts: THUMBNAIL_HOSTS
        ),
      }.compact
    rescue *Mastodon::HTTP_CONNECTION_ERRORS,
           Mastodon::HostValidationError,
           Mastodon::LengthValidationError,
           JSON::ParserError
      raise Account::ProfileMusic::Provider::Error
    end

    def extract_track_id(html)
      encoded_track = html.to_s.match(/api\.soundcloud\.com%2Ftracks%2F(\d+)/)
      return encoded_track[1] if encoded_track

      decoded_track = html.to_s.match(%r{api\.soundcloud\.com/tracks/(\d+)})
      decoded_track && decoded_track[1]
    end

    def title(data)
      raw_title = Account::ProfileMusic::Provider.sanitize_text(data['title'])
      author = Account::ProfileMusic::Provider.sanitize_text(data['author_name'])
      raw_title.delete_suffix(" by #{author}").presence || 'SoundCloud track'
    end

    def embed_url(track_id)
      "https://w.soundcloud.com/player/?#{Rack::Utils.build_query(url: "https://api.soundcloud.com/tracks/#{track_id}")}"
    end
  end
end
