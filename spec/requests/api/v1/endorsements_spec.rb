# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Endorsements' do
  include_context 'with API authentication'

  describe 'GET /api/v1/endorsements' do
    context 'when not authorized' do
      it 'returns http unauthorized' do
        get api_v1_endorsements_path

        expect(response)
          .to have_http_status(401)
        expect(response.content_type)
          .to start_with('application/json')
      end
    end

    context 'with wrong scope' do
      before do
        get api_v1_endorsements_path, headers: headers
      end

      it_behaves_like 'forbidden for wrong scope', 'write write:accounts'
    end

    context 'with correct scope' do
      let(:scopes) { 'read:accounts' }

      context 'with endorsed accounts' do
        let!(:first_account_pin) { Fabricate(:account_pin, account: user.account, position: 2) }
        let!(:second_account_pin) { Fabricate(:account_pin, account: user.account, position: 1) }

        it 'returns http success and accounts json in top 8 order' do
          get api_v1_endorsements_path, headers: headers

          expect(response)
            .to have_http_status(200)
          expect(response.content_type)
            .to start_with('application/json')

          expect(response.parsed_body)
            .to be_present
          expect(response.parsed_body.pluck('id')).to eq [second_account_pin.target_account_id.to_s, first_account_pin.target_account_id.to_s]
        end
      end

      context 'with legacy pins beyond top 8' do
        let!(:first_account_pin) { Fabricate(:account_pin, account: user.account, position: 1) }
        let!(:overflow_account_pin) { Fabricate(:account_pin, account: user.account, position: 9) }

        it 'does not return accounts outside the top 8 positions' do
          get api_v1_endorsements_path, headers: headers

          expect(response.parsed_body.pluck('id')).to eq [first_account_pin.target_account_id.to_s]
          expect(response.parsed_body.pluck('id')).to_not include(overflow_account_pin.target_account_id.to_s)
        end
      end

      context 'without endorsed accounts without json' do
        it 'returns http success' do
          get api_v1_endorsements_path, headers: headers

          expect(response)
            .to have_http_status(200)
          expect(response.content_type)
            .to start_with('application/json')

          expect(response.parsed_body)
            .to_not be_present
        end
      end
    end
  end

  describe 'PATCH /api/v1/endorsements' do
    let(:scopes) { 'write:accounts' }
    let!(:first_account_pin) { Fabricate(:account_pin, account: user.account, position: 1) }
    let!(:second_account_pin) { Fabricate(:account_pin, account: user.account, position: 2) }

    it 'reorders top 8 accounts', :aggregate_failures do
      patch api_v1_endorsements_path, params: { account_ids: [second_account_pin.target_account_id.to_s, first_account_pin.target_account_id.to_s] }, headers: headers

      expect(response).to have_http_status(200)
      expect(response.parsed_body.pluck('id')).to eq [second_account_pin.target_account_id.to_s, first_account_pin.target_account_id.to_s]
      expect(first_account_pin.reload.position).to eq 2
      expect(second_account_pin.reload.position).to eq 1
    end

    it 'rejects duplicate account ids', :aggregate_failures do
      patch api_v1_endorsements_path, params: { account_ids: [first_account_pin.target_account_id.to_s, first_account_pin.target_account_id.to_s] }, headers: headers

      expect(response).to have_http_status(422)
      expect(first_account_pin.reload.position).to eq 1
      expect(second_account_pin.reload.position).to eq 2
    end

    it 'rejects missing account ids', :aggregate_failures do
      patch api_v1_endorsements_path, params: { account_ids: [first_account_pin.target_account_id.to_s] }, headers: headers

      expect(response).to have_http_status(422)
      expect(first_account_pin.reload.position).to eq 1
      expect(second_account_pin.reload.position).to eq 2
    end

    context 'with legacy pins beyond top 8' do
      let!(:overflow_account_pin) { Fabricate(:account_pin, account: user.account, position: 9) }

      it 'reorders only the top 8 pins', :aggregate_failures do
        patch api_v1_endorsements_path, params: { account_ids: [second_account_pin.target_account_id.to_s, first_account_pin.target_account_id.to_s] }, headers: headers

        expect(response).to have_http_status(200)
        expect(first_account_pin.reload.position).to eq 2
        expect(second_account_pin.reload.position).to eq 1
        expect(overflow_account_pin.reload.position).to eq 9
      end
    end
  end
end
