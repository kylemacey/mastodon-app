# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountPin do
  describe 'Associations' do
    it { is_expected.to belong_to(:account).required }
    it { is_expected.to belong_to(:target_account).required }
  end

  describe 'Validations' do
    describe 'the top 8 limit' do
      subject { Fabricate.build(:account_pin, account:) }

      let(:account) { Fabricate(:account) }

      before do
        Fabricate.times(AccountPin::TOP_8_LIMIT, :account_pin, account:)
        account.follow!(subject.target_account)
      end

      it { is_expected.to_not allow_value(subject.target_account).for(:target_account).against(:base).with_message(I18n.t('accounts.pin_errors.limit', count: AccountPin::TOP_8_LIMIT)) }
    end

    describe 'the follow relationship' do
      subject { Fabricate.build :account_pin, account: account }

      let(:account) { Fabricate :account }
      let(:target_account) { Fabricate :account }

      context 'when account is following target account' do
        before { account.follow!(target_account) }

        it { is_expected.to allow_value(target_account).for(:target_account).against(:base) }
      end

      context 'when account is not following target account' do
        it { is_expected.to_not allow_value(target_account).for(:target_account).against(:base).with_message(not_following_message) }

        def not_following_message
          I18n.t('accounts.pin_errors.following')
        end
      end
    end
  end

  describe 'Creation' do
    let(:account) { Fabricate(:account) }

    it 'assigns the next top 8 position' do
      first_pin = Fabricate(:account_pin, account:)
      second_pin = Fabricate(:account_pin, account:)

      expect(first_pin.position).to eq 1
      expect(second_pin.position).to eq 2
    end

    it 'fills the first available top 8 position when legacy overflow pins exist' do
      Fabricate(:account_pin, account:, position: 1)
      overflow_pin = Fabricate.build(:account_pin, account:, position: 9)
      account.follow!(overflow_pin.target_account)
      overflow_pin.save!(validate: false)

      new_pin = Fabricate(:account_pin, account:)

      expect(new_pin.position).to eq 2
    end

    it 'does not count suspended top 8 pins against the visible limit' do
      Fabricate.times(AccountPin::TOP_8_LIMIT - 1, :account_pin, account:)
      suspended_account = Fabricate(:account, suspended_at: Time.current)
      account.follow!(suspended_account)
      Fabricate(:account_pin, account:, target_account: suspended_account)

      new_pin = Fabricate(:account_pin, account:)

      expect(new_pin.position).to eq AccountPin::TOP_8_LIMIT
    end
  end

  describe '.endorsed_map' do
    let(:account) { Fabricate(:account) }

    it 'only maps accounts in top 8 positions as endorsed' do
      overflow_pin = Fabricate.build(:account_pin, account:, position: 9)
      account.follow!(overflow_pin.target_account)
      overflow_pin.save!(validate: false)

      expect(Account.endorsed_map([overflow_pin.target_account_id], account.id)).to be_empty
    end
  end
end
