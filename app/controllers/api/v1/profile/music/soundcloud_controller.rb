# frozen_string_literal: true

class Api::V1::Profile::Music::SoundcloudController < Api::BaseController
  before_action do
    doorkeeper_authorize! :profile, :read, :'read:accounts', :write, :'write:accounts'
  end
  before_action :require_user!

  def index
    render json: ProfileMusic::SoundcloudSearchService.new.call(params[:q], limit: limit_param(10))
  rescue ProfileMusic::SoundcloudSearchService::MissingConfigurationError
    render json: { error: 'SoundCloud search is not configured' }, status: 503
  rescue ProfileMusic::SoundcloudSearchService::UnexpectedResponseError
    render json: { error: 'SoundCloud search is temporarily unavailable' }, status: 503
  end
end
