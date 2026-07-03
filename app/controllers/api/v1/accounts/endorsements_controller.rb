# frozen_string_literal: true

class Api::V1::Accounts::EndorsementsController < Api::BaseController
  include Authorization

  before_action -> { authorize_if_got_token! :read, :'read:accounts' }, only: :index
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }, except: :index
  before_action :require_user!, except: :index
  before_action :set_account
  before_action :set_endorsed_accounts, only: :index
  after_action :insert_pagination_headers, only: :index

  def index
    cache_if_unauthenticated!
    render json: @endorsed_accounts, each_serializer: REST::AccountSerializer
  end

  def create
    AccountPin.transaction do
      AccountPin.demote_unavailable_top_eight!(current_account.id)

      account_pin = AccountPin.find_or_initialize_by(account: current_account, target_account: @account)
      account_pin.persisted? ? account_pin.promote_to_top_eight! : account_pin.save!
    end

    render json: @account, serializer: REST::RelationshipSerializer, relationships: relationships_presenter
  end

  def destroy
    pin = AccountPin.find_by(account: current_account, target_account: @account)
    pin&.destroy!
    render json: @account, serializer: REST::RelationshipSerializer, relationships: relationships_presenter
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def set_endorsed_accounts
    @endorsed_accounts = @account.unavailable? ? [] : paginated_endorsed_accounts
  end

  def paginated_endorsed_accounts
    @account.account_pins
      .top_eight
      .includes(target_account: [:account_stat, :user])
      .filter_map(&:target_account)
      .reject(&:suspended?)
  end

  def relationships_presenter
    AccountRelationshipsPresenter.new([@account], current_user.account_id)
  end

  def next_path
    api_v1_account_endorsements_url pagination_params(max_id: pagination_max_id) if records_continue?
  end

  def prev_path
    nil
  end

  def pagination_collection
    @endorsed_accounts
  end

  def records_continue?
    false
  end
end
