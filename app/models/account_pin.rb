# frozen_string_literal: true

# == Schema Information
#
# Table name: account_pins
#
#  id                :bigint(8)        not null, primary key
#  position          :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint(8)        not null
#  target_account_id :bigint(8)        not null
#

class AccountPin < ApplicationRecord
  TOP_8_LIMIT = 8

  include Paginable
  include RelationshipCacheable

  belongs_to :account
  belongs_to :target_account, class_name: 'Account'

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :account_id }

  validate :validate_follow_relationship
  validate :validate_top_8_limit, on: :create

  before_validation :free_unavailable_top_eight_positions, on: :create
  before_validation :set_position, on: :create

  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :top_eight, -> { where(position: 1..TOP_8_LIMIT) }
  scope :with_unsuspended_target, -> { joins(:target_account).merge(Account.without_suspended) }

  def self.demote_unavailable_top_eight!(account_id)
    return if account_id.blank?

    unavailable_pins = where(account_id:).top_eight.includes(:target_account).select { |account_pin| account_pin.target_account.suspended? }
    next_position = where(account_id:).maximum(:position).to_i

    unavailable_pins.each do |account_pin|
      next_position += 1
      account_pin.update_columns(position: next_position, updated_at: Time.current)
    end
  end

  def promote_to_top_eight!
    return if position <= TOP_8_LIMIT

    self.class.demote_unavailable_top_eight!(account_id)
    if self.class.where(account_id:).top_eight.with_unsuspended_target.count >= TOP_8_LIMIT
      add_top_eight_limit_error
      raise ActiveRecord::RecordInvalid, self
    end

    update!(position: first_available_top_8_position)
  end

  private

  def free_unavailable_top_eight_positions
    self.class.demote_unavailable_top_eight!(account_id)
  end

  def set_position
    self.position ||= first_available_top_8_position
  end

  def validate_follow_relationship
    errors.add(:base, I18n.t('accounts.pin_errors.following')) unless account&.following?(target_account)
  end

  def validate_top_8_limit
    return if account_id.blank?

    add_top_eight_limit_error if self.class.where(account_id:).top_eight.with_unsuspended_target.count >= TOP_8_LIMIT
  end

  def first_available_top_8_position
    used_positions = self.class.where(account_id:).top_eight.pluck(:position)

    (1..TOP_8_LIMIT).find { |position| used_positions.exclude?(position) } || (TOP_8_LIMIT + 1)
  end

  def add_top_eight_limit_error
    errors.add(:base, I18n.t('accounts.pin_errors.limit', count: TOP_8_LIMIT))
  end
end
