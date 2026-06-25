# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts Pins API' do
  include_context 'with API authentication', oauth_scopes: 'write:accounts'

  let(:kevin) { Fabricate(:user) }

  before do
    kevin.account.followers << user.account
  end

  describe 'GET /api/v1/accounts/:account_id/endorsements' do
    subject { get "/api/v1/accounts/#{user.account.id}/endorsements", headers: headers }

    let(:scopes) { 'read:accounts' }
    let(:amy) { Fabricate(:user) }

    before do
      Fabricate(:account_pin, account: user.account, target_account: kevin.account, position: 2)
      Fabricate(:account_pin, account: user.account, target_account: amy.account, position: 1)
    end

    it 'returns the expected accounts in top 8 order', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')
      expect(response.parsed_body.pluck('id')).to eq [amy.account_id.to_s, kevin.account_id.to_s]
    end

    context 'with legacy pins beyond top 8' do
      let(:overflow_account) { Fabricate(:account) }

      before do
        user.account.follow!(overflow_account)
        AccountPin.create!(account: user.account, target_account: overflow_account, position: 9)
      end

      it 'does not return accounts outside the top 8 positions' do
        subject

        expect(response.parsed_body.pluck('id')).to_not include(overflow_account.id.to_s)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/endorse' do
    subject { post "/api/v1/accounts/#{kevin.account.id}/endorse", headers: headers }

    it 'creates account_pin', :aggregate_failures do
      expect do
        subject
      end.to change { AccountPin.where(account: user.account, target_account: kevin.account).count }.by(1)
      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')
    end

    context 'when the current user already has 8 accounts pinned' do
      before do
        Fabricate.times(AccountPin::TOP_8_LIMIT, :account_pin, account: user.account)
      end

      it 'does not create a ninth account pin', :aggregate_failures do
        expect do
          subject
        end.to_not change(AccountPin, :count)
        expect(response).to have_http_status(422)
      end
    end

    context 'when the account already has a preserved legacy pin outside the top 8' do
      before do
        AccountPin.create!(account: user.account, target_account: kevin.account, position: 9)
      end

      it 'promotes the existing account pin into the top 8', :aggregate_failures do
        expect do
          subject
        end.to_not change(AccountPin, :count)

        expect(response).to have_http_status(200)
        expect(AccountPin.find_by(account: user.account, target_account: kevin.account).position).to eq 1
      end
    end

    context 'when a suspended account is occupying a top 8 position' do
      let(:suspended_account) { Fabricate(:account, suspended_at: Time.current) }

      before do
        Fabricate.times(AccountPin::TOP_8_LIMIT - 1, :account_pin, account: user.account)
        user.account.follow!(suspended_account)
        AccountPin.create!(account: user.account, target_account: suspended_account, position: AccountPin::TOP_8_LIMIT)
      end

      it 'demotes the suspended pin and creates a visible replacement', :aggregate_failures do
        expect do
          subject
        end.to change(AccountPin, :count).by(1)

        expect(response).to have_http_status(200)
        expect(AccountPin.find_by(account: user.account, target_account: kevin.account).position).to eq AccountPin::TOP_8_LIMIT
        expect(AccountPin.find_by(account: user.account, target_account: suspended_account).position).to eq AccountPin::TOP_8_LIMIT + 1
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/unendorse' do
    subject { post "/api/v1/accounts/#{kevin.account.id}/unendorse", headers: headers }

    before do
      Fabricate(:account_pin, account: user.account, target_account: kevin.account)
    end

    it 'destroys account_pin', :aggregate_failures do
      expect do
        subject
      end.to change { AccountPin.where(account: user.account, target_account: kevin.account).count }.by(-1)
      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')
    end
  end
end
