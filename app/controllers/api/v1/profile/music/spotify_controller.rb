# frozen_string_literal: true

class Api::V1::Profile::Music::SpotifyController < Api::BaseController
  before_action do
    doorkeeper_authorize! :profile, :read, :'read:accounts', :write, :'write:accounts'
  end
  before_action :require_user!

  def index
    render json: ProfileMusic::SpotifySearchService.new.call(params[:q], limit: limit_param(10))
  rescue ProfileMusic::SpotifySearchService::MissingConfigurationError
    render json: { error: 'Spotify search is not configured' }, status: 503
  rescue ProfileMusic::SpotifySearchService::UnexpectedResponseError
    render json: { error: 'Spotify search is temporarily unavailable' }, status: 503
  end
end
