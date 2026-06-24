# frozen_string_literal: true

class ProfileMusic::SpotifySearchService < BaseService
  TOKEN_URL = 'https://accounts.spotify.com/api/token'
  SEARCH_URL = 'https://api.spotify.com/v1/search'
  CACHE_KEY = 'profile_music:spotify:access_token'

  MissingConfigurationError = Class.new(StandardError)
  UnexpectedResponseError = Class.new(StandardError)

  def call(query, limit: 5)
    raise MissingConfigurationError unless configured?

    query = query.to_s.squish
    return [] if query.blank?

    response = spotify_get(
      "#{SEARCH_URL}?#{Rack::Utils.build_query(q: query, type: 'track', limit: limit.clamp(1, 10))}"
    )

    Array(response.dig('tracks', 'items')).filter_map do |track|
      Account::ProfileMusic::Provider::Spotify.from_api(track)&.merge('featured' => false)
    end
  end

  private

  def configured?
    client_id.present? && client_secret.present?
  end

  def spotify_get(url)
    Request.new(:get, url).add_headers(
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
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
    ENV.fetch('SPOTIFY_CLIENT_ID', nil)
  end

  def client_secret
    ENV.fetch('SPOTIFY_CLIENT_SECRET', nil)
  end
end
