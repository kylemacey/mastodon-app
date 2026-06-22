# frozen_string_literal: true

class Api::V1::Profile::BackgroundsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }
  before_action :require_user!

  def destroy
    @account = current_account
    UpdateAccountService.new.call(@account, { profile_background: nil }, raise_error: true)
    render json: @account, serializer: REST::ProfileSerializer
  end
end
