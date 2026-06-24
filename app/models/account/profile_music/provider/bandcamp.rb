# frozen_string_literal: true

class Account::ProfileMusic::Provider::Bandcamp
  KEY = 'bandcamp'
  TRACK_PAGE_PATTERN = %r{\A/track/[^/]+/?\z}
  THUMBNAIL_HOSTS = %w(.bcbits.com).freeze

  class << self
    def handles?(attributes)
      provider_name(attributes) == KEY || bandcamp_track_url?(attributes['url'] || attributes[:url])
    end

    def normalize(attributes, existing_item = nil)
      url = canonical_url_for(attributes)
      return if url.blank?

      if reusable_existing_item?(existing_item)
        return existing_item.merge('url' => url, 'embed_url' => embed_url(existing_item['provider_id']))
      end

      resolve(url)
    end

    def normalize_stored(attributes)
      track_id = attributes['provider_id'].to_s
      return if track_id.blank?

      {
        'provider' => KEY,
        'provider_id' => track_id,
        'url' => canonical_url_for(attributes),
        'embed_url' => embed_url(track_id),
        'title' => Account::ProfileMusic::Provider.sanitize_text(attributes['title']).presence || 'Bandcamp track',
        'artist' => Account::ProfileMusic::Provider.sanitize_text(attributes['artist']),
        'thumbnail_url' => Account::ProfileMusic::Provider.valid_https_url?(
          attributes['thumbnail_url'],
          allowed_hosts: THUMBNAIL_HOSTS
        ),
      }.compact
    end

    def canonical_url_for(attributes)
      url = (attributes['url'] || attributes[:url]).to_s.strip
      uri = Addressable::URI.parse(url)
      return unless uri.scheme == 'https' && bandcamp_host?(uri.host) && TRACK_PAGE_PATTERN.match?(uri.path.to_s)

      uri.query = nil
      uri.fragment = nil
      uri.to_s.delete_suffix('/')
    rescue Addressable::URI::InvalidURIError
      nil
    end

    private

    def provider_name(attributes)
      (attributes['provider'] || attributes[:provider]).to_s
    end

    def bandcamp_track_url?(url)
      canonical_url_for('url' => url).present?
    end

    def bandcamp_host?(host)
      host == 'bandcamp.com' || host&.end_with?('.bandcamp.com')
    end

    def reusable_existing_item?(item)
      item.present? && item['provider_id'].present?
    end

    def resolve(url)
      body = Request.new(:get, url).add_headers('Accept' => 'text/html').perform do |response|
        unless response.code == 200 && response.mime_type == 'text/html'
          raise Account::ProfileMusic::Provider::Error
        end

        response.body_with_limit
      end

      document = Nokogiri::HTML5(body)
      track_id = bandcamp_page_properties(document)['item_id'] || music_recording_property(document, 'track_id')
      raise Account::ProfileMusic::Provider::Error if track_id.blank?

      {
        'provider' => KEY,
        'provider_id' => track_id.to_s,
        'url' => url,
        'embed_url' => embed_url(track_id),
        'title' => title(document),
        'artist' => artist(document),
        'thumbnail_url' => thumbnail_url(document),
      }.compact
    rescue *Mastodon::HTTP_CONNECTION_ERRORS,
           Mastodon::HostValidationError,
           Mastodon::LengthValidationError,
           JSON::ParserError,
           Nokogiri::SyntaxError
      raise Account::ProfileMusic::Provider::Error
    end

    def bandcamp_page_properties(document)
      content = document.at_css('meta[name="bc-page-properties"]')&.attr('content')
      return {} if content.blank?

      data = JSON.parse(content)
      data['item_type'] == 't' ? data : {}
    end

    def music_recording(document)
      document.css('script[type="application/ld+json"]').filter_map do |node|
        data = JSON.parse(node.text)
        data if data['@type'] == 'MusicRecording'
      rescue JSON::ParserError
        nil
      end.first || {}
    end

    def music_recording_property(document, name)
      Array(music_recording(document)['additionalProperty']).find do |property|
        property['name'] == name
      end&.fetch('value', nil)
    end

    def title(document)
      Account::ProfileMusic::Provider.sanitize_text(music_recording(document)['name']).presence ||
        Account::ProfileMusic::Provider.sanitize_text(og_title(document)&.split(', by ')&.first).presence ||
        'Bandcamp track'
    end

    def artist(document)
      Account::ProfileMusic::Provider.sanitize_text(music_recording(document).dig('byArtist', 'name')).presence ||
        Account::ProfileMusic::Provider.sanitize_text(og_title(document)&.split(', by ')&.second)
    end

    def thumbnail_url(document)
      Account::ProfileMusic::Provider.valid_https_url?(
        music_recording(document)['image'] || document.at_css('meta[property="og:image"]')&.attr('content'),
        allowed_hosts: THUMBNAIL_HOSTS
      )
    end

    def og_title(document)
      document.at_css('meta[property="og:title"]')&.attr('content')
    end

    def embed_url(track_id)
      "https://bandcamp.com/EmbeddedPlayer/track=#{track_id}/size=small/bgcol=ffffff/linkcol=0687f5/transparent=true/"
    end
  end
end
