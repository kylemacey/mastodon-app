# frozen_string_literal: true

class ProfileMusic::SoundcloudSearchService < BaseService
  TOKEN_URL = 'https://secure.soundcloud.com/oauth/token'
  RESOLVE_URL = 'https://api.soundcloud.com/resolve'
  SEARCH_URL = 'https://api.soundcloud.com/tracks'
  CACHE_KEY = 'profile_music:soundcloud:access_token'

  class MissingConfigurationError < StandardError; end
  class UnexpectedResponseError < StandardError; end

  def call(query, limit: 5)
    raise MissingConfigurationError unless configured?

    query = query.to_s.squish
    return [] if query.blank?

    response = soundcloud_get(
      "#{SEARCH_URL}?#{Rack::Utils.build_query(q: query, access: 'playable', limit: limit.clamp(1, 10))}"
    )

    Array(response).filter_map do |track|
      Account::ProfileMusic::Provider::Soundcloud.from_api(track)&.merge('featured' => false)
    end
  end

  def find_track(track_id)
    raise MissingConfigurationError unless configured?

    track_id = track_id.to_s
    return if track_id.blank?

    Account::ProfileMusic::Provider::Soundcloud.from_api(
      soundcloud_get("#{SEARCH_URL}/#{track_id}")
    )
  end

  def resolve_url(url)
    raise MissingConfigurationError unless configured?

    url = url.to_s.squish
    return if url.blank?

    Account::ProfileMusic::Provider::Soundcloud.from_api(
      soundcloud_get("#{RESOLVE_URL}?#{Rack::Utils.build_query(url: url)}")
    )
  end

  private

  def configured?
    client_id.present? && client_secret.present?
  end

  def soundcloud_get(url)
    Request.new(:get, url).add_headers(
      'Accept' => 'application/json',
      'Authorization' => "OAuth #{access_token}"
    ).perform do |response|
      raise UnexpectedResponseError unless response.code == 200

      JSON.parse(response.body_with_limit)
    end
  rescue *Mastodon::HTTP_CONNECTION_ERRORS,
         Mastodon::HostValidationError,
         Mastodon::LengthValidationError,
         JSON::ParserError
    raise UnexpectedResponseError
  end

  def access_token
    Rails.cache.read(CACHE_KEY).presence || fetch_access_token
  end

  def fetch_access_token
    body = Rack::Utils.build_query(grant_type: 'client_credentials')
    authorization = Base64.strict_encode64("#{client_id}:#{client_secret}")

    token_response = Request.new(:post, TOKEN_URL, body: body).add_headers(
      'Accept' => 'application/json',
      'Authorization' => "Basic #{authorization}",
      'Content-Type' => 'application/x-www-form-urlencoded'
    ).perform do |response|
      raise UnexpectedResponseError unless response.code == 200

      JSON.parse(response.body_with_limit)
    end

    token = token_response['access_token']
    raise UnexpectedResponseError if token.blank?

    Rails.cache.write(
      CACHE_KEY,
      token,
      expires_in: [token_response['expires_in'].to_i - 60, 60].max.seconds
    )
    token
  rescue *Mastodon::HTTP_CONNECTION_ERRORS,
         Mastodon::HostValidationError,
         Mastodon::LengthValidationError,
         JSON::ParserError
    raise UnexpectedResponseError
  end

  def client_id
    ENV.fetch('SOUNDCLOUD_CLIENT_ID', nil)
  end

  def client_secret
    ENV.fetch('SOUNDCLOUD_CLIENT_SECRET', nil)
  end
end
