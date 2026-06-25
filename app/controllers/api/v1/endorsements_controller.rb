# frozen_string_literal: true

class Api::V1::EndorsementsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:accounts' }, only: :index
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }, only: :update

  before_action :require_user!

  after_action :insert_pagination_headers, only: :index

  def index
    @accounts = load_accounts
    render json: @accounts, each_serializer: REST::AccountSerializer
  end

  def update
    reorder_account_pins!

    @accounts = ordered_endorsed_accounts
    render json: @accounts, each_serializer: REST::AccountSerializer
  end

  private

  def load_accounts
    ordered_endorsed_accounts
  end

  def ordered_endorsed_accounts
    current_account.account_pins
      .top_eight
      .includes(target_account: [:account_stat, :user])
      .filter_map(&:target_account)
      .reject(&:suspended?)
  end

  def reorder_account_pins!
    requested_account_ids = Array(resource_params[:account_ids]).map(&:to_s)
    account_pins = current_account.account_pins.top_eight.includes(:target_account).to_a
    visible_account_pins, hidden_account_pins = account_pins.partition { |account_pin| !account_pin.target_account.suspended? }
    current_account_ids = visible_account_pins.map { |account_pin| account_pin.target_account_id.to_s }

    unless requested_account_ids.size <= AccountPin::TOP_8_LIMIT &&
           requested_account_ids.uniq == requested_account_ids &&
           requested_account_ids.sort == current_account_ids.sort
      raise Mastodon::ValidationError, I18n.t('accounts.pin_errors.reorder')
    end

    account_pins_by_target_account_id = account_pins.index_by { |account_pin| account_pin.target_account_id.to_s }

    AccountPin.transaction do
      account_pins.each_with_index do |account_pin, index|
        account_pin.update_columns(position: -(index + 1), updated_at: Time.current)
      end

      ordered_account_ids = requested_account_ids + hidden_account_pins.map { |account_pin| account_pin.target_account_id.to_s }

      ordered_account_ids.each_with_index do |account_id, index|
        account_pins_by_target_account_id.fetch(account_id).update_columns(position: index + 1, updated_at: Time.current)
      end
    end
  end

  def resource_params
    params.permit(account_ids: [])
  end

  def next_path
    nil
  end

  def prev_path
    nil
  end

  def pagination_collection
    @accounts
  end

  def records_continue?
    false
  end
end
