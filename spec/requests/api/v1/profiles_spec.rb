# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile API' do
  include_context 'with API authentication'

  let(:scopes) { 'write:accounts' }

  let(:account) do
    Fabricate(
      :account,
      avatar: fixture_file_upload('avatar.gif', 'image/gif'),
      header: fixture_file_upload('attachment.jpg', 'image/jpeg'),
      profile_background: fixture_file_upload('attachment.jpg', 'image/jpeg'),
      profile_background_color: '#112233',
      profile_accent_color: '#445566',
      profile_font: 'mono',
      profile_custom_css: '.account__header { color: hotpink; }'
    )
  end
  let(:user) { account.user }

  describe 'GET /api/v1/profile' do
    let(:scopes) { 'read:accounts' }

    it 'returns HTTP success with the appropriate profile' do
      get '/api/v1/profile', headers: headers

      expect(response)
        .to have_http_status(200)

      expect(response.content_type)
        .to start_with('application/json')

      expect(response.parsed_body)
        .to match(
          'id' => account.id.to_s,
          'avatar' => %r{https://.*},
          'avatar_static' => %r{https://.*},
          'avatar_description' => '',
          'header' => %r{https://.*},
          'header_static' => %r{https://.*},
          'header_description' => '',
          'profile_background' => %r{https://.*},
          'profile_background_static' => %r{https://.*},
          'profile_background_color' => '#112233',
          'profile_accent_color' => '#445566',
          'profile_font' => 'mono',
          'profile_custom_css' => '.account__header { color: hotpink; }',
          'profile_music' => [],
          'hide_collections' => anything,
          'bot' => account.bot,
          'locked' => account.locked,
          'discoverable' => account.discoverable,
          'indexable' => account.indexable,
          'display_name' => account.display_name,
          'fields' => [],
          'formatted_fields' => [],
          'attribution_domains' => [],
          'note' => account.note,
          'formatted_note' => account.note,
          'show_featured' => account.show_featured,
          'show_media' => account.show_media,
          'show_media_replies' => account.show_media_replies,
          'featured_tags' => []
        )
    end
  end

  describe 'PATCH /api/v1/profile' do
    subject do
      patch '/api/v1/profile', headers: headers, params: params
    end

    let(:soundcloud_url) { 'https://soundcloud.com/odesza/line-of-sight-feat-wynne-mansionair' }
    let(:soundcloud_iframe) do
      '<iframe src="https://w.soundcloud.com/player/?url=' \
        'https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F319412512&show_artwork=true"></iframe>'
    end

    let(:params) do
      {
        avatar: fixture_file_upload('avatar.gif', 'image/gif'),
        avatar_description: 'animated walking round cat',
        discoverable: true,
        display_name: "Alice Isn't Dead",
        header: fixture_file_upload('attachment.jpg', 'image/jpeg'),
        indexable: true,
        locked: false,
        note: 'Hello!',
        profile_background: fixture_file_upload('attachment.jpg', 'image/jpeg'),
        profile_background_color: '#abc',
        profile_accent_color: 'def',
        profile_font: 'pixel',
        profile_custom_css: '.account__header { color: red; }',
        attribution_domains: ['example.com'],
        fields_attributes: [
          { name: 'pronouns', value: 'she/her' },
          { name: 'foo', value: 'bar' },
        ],
        profile_music: {
          '0' => {
            url: soundcloud_url,
          },
        },
      }
    end

    before do
      stub_request(:get, 'https://soundcloud.com/oembed')
        .with(query: { format: 'json', url: soundcloud_url })
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body: JSON.dump(
            title: 'Line Of Sight (feat. WYNNE & Mansionair) by ODESZA',
            author_name: 'ODESZA',
            thumbnail_url: 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg',
            html: soundcloud_iframe
          )
        )
    end

    it_behaves_like 'forbidden for wrong scope', 'read read:accounts'

    describe 'with invalid data' do
      let(:params) { { note: 'a' * 2 * Account::NOTE_LENGTH_LIMIT } }

      it 'returns http unprocessable entity' do
        subject
        expect(response).to have_http_status(422)
        expect(response.content_type)
          .to start_with('application/json')
        expect(response.parsed_body)
          .to include(
            error: /Validation failed/,
            details: include(note: contain_exactly(include(error: 'ERR_TOO_LONG', description: /too long/)))
          )
      end
    end

    it 'returns http success with updated JSON attributes' do
      subject

      expect(response)
        .to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')
      expect(response.parsed_body)
        .to include({
          locked: false,
        })
      expect(user.account.reload)
        .to have_attributes(
          display_name: eq("Alice Isn't Dead"),
          note: 'Hello!',
          avatar: exist,
          avatar_description: 'animated walking round cat',
          header: exist,
          profile_background: exist,
          profile_background_color: '#AABBCC',
          profile_accent_color: '#DDEEFF',
          profile_font: 'pixel',
          profile_custom_css: '.account__header { color: red; }',
          attribution_domains: ['example.com'],
          profile_music: contain_exactly(
            include(
              'provider' => 'soundcloud',
              'provider_id' => '319412512',
              'title' => 'Line Of Sight (feat. WYNNE & Mansionair)'
            )
          ),
          fields: contain_exactly(
            have_attributes(
              name: 'pronouns',
              value: 'she/her'
            ),
            have_attributes(
              name: 'foo',
              value: 'bar'
            )
          )
        )
      expect(ActivityPub::UpdateDistributionWorker)
        .to have_enqueued_sidekiq_job(user.account_id)
      expect(response.parsed_body['profile_music'])
        .to contain_exactly(
          include(
            'provider' => 'soundcloud',
            'provider_id' => '319412512',
            'title' => 'Line Of Sight (feat. WYNNE & Mansionair)',
            'featured' => true
          )
        )
    end
  end

  describe 'GET /api/v1/profile/music/spotify' do
    let(:scopes) { 'write:accounts' }

    before do
      Rails.cache.delete(ProfileMusic::SpotifySearchService::CACHE_KEY)
    end

    it 'returns service unavailable when Spotify is not configured' do
      get '/api/v1/profile/music/spotify', headers: headers, params: { q: 'aphasia' }

      expect(response).to have_http_status(503)
      expect(response.parsed_body)
        .to include(error: 'Spotify search is not configured')
    end

    it 'returns normalized Spotify tracks' do
      ClimateControl.modify SPOTIFY_CLIENT_ID: 'client', SPOTIFY_CLIENT_SECRET: 'secret' do
        stub_request(:post, 'https://accounts.spotify.com/api/token')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.dump(access_token: 'token', expires_in: 3600)
          )
        stub_request(:get, 'https://api.spotify.com/v1/search')
          .with(query: hash_including('q' => 'aphasia', 'type' => 'track', 'limit' => '10'))
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.dump(
              tracks: {
                items: [
                  {
                    id: '3n3Ppam7vgaVa1iaRUc9Lp',
                    name: 'Aphasia',
                    artists: [{ name: 'Pinegrove' }],
                    external_urls: { spotify: 'https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp' },
                    album: { images: [{ url: 'https://i.scdn.co/image/example' }] },
                  },
                ],
              }
            )
          )

        get '/api/v1/profile/music/spotify', headers: headers, params: { q: 'aphasia' }
      end

      expect(response).to have_http_status(200)
      expect(response.parsed_body)
        .to contain_exactly(
          include(
            'provider' => 'spotify',
            'provider_id' => '3n3Ppam7vgaVa1iaRUc9Lp',
            'title' => 'Aphasia',
            'artist' => 'Pinegrove',
            'embed_url' => 'https://open.spotify.com/embed/track/3n3Ppam7vgaVa1iaRUc9Lp',
            'featured' => false
          )
        )
    end
  end

  describe 'GET /api/v1/profile/music/soundcloud' do
    let(:scopes) { 'write:accounts' }

    before do
      Rails.cache.delete(ProfileMusic::SoundcloudSearchService::CACHE_KEY)
    end

    it 'returns service unavailable when SoundCloud is not configured' do
      get '/api/v1/profile/music/soundcloud', headers: headers, params: { q: 'line of sight' }

      expect(response).to have_http_status(503)
      expect(response.parsed_body)
        .to include(error: 'SoundCloud search is not configured')
    end

    it 'returns normalized SoundCloud tracks' do
      ClimateControl.modify SOUNDCLOUD_CLIENT_ID: 'client', SOUNDCLOUD_CLIENT_SECRET: 'secret' do
        stub_request(:post, 'https://secure.soundcloud.com/oauth/token')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.dump(access_token: 'token', expires_in: 3600)
          )
        stub_request(:get, 'https://api.soundcloud.com/tracks')
          .with(query: hash_including('q' => 'line of sight', 'access' => 'playable', 'limit' => '10'))
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.dump(
              [
                {
                  id: 319_412_512,
                  title: 'Line Of Sight (feat. WYNNE & Mansionair)',
                  permalink_url: 'https://soundcloud.com/odesza/line-of-sight-feat-wynne-mansionair',
                  artwork_url: 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg',
                  user: { username: 'ODESZA' },
                },
              ]
            )
          )

        get '/api/v1/profile/music/soundcloud', headers: headers, params: { q: 'line of sight' }
      end

      expect(response).to have_http_status(200)
      expect(response.parsed_body)
        .to contain_exactly(
          include(
            'provider' => 'soundcloud',
            'provider_id' => '319412512',
            'title' => 'Line Of Sight (feat. WYNNE & Mansionair)',
            'artist' => 'ODESZA',
            'url' => 'https://soundcloud.com/odesza/line-of-sight-feat-wynne-mansionair',
            'embed_url' => 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F319412512',
            'featured' => false
          )
        )
    end
  end

  describe 'DELETE /api/v1/profile/avatar' do
    context 'with wrong scope' do
      before do
        delete '/api/v1/profile/avatar', headers: headers
      end

      it_behaves_like 'forbidden for wrong scope', 'read'
    end

    it 'returns http success and deletes the avatar, preserves the header, queues up distribution' do
      delete '/api/v1/profile/avatar', headers: headers

      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')

      account.reload
      expect(account.avatar).to_not exist
      expect(account.header).to exist
      expect(ActivityPub::UpdateDistributionWorker)
        .to have_enqueued_sidekiq_job(account.id)
    end
  end

  describe 'DELETE /api/v1/profile/header' do
    context 'with wrong scope' do
      before do
        delete '/api/v1/profile/header', headers: headers
      end

      it_behaves_like 'forbidden for wrong scope', 'read'
    end

    it 'returns http success, preserves the avatar, deletes the header, queues up distribution' do
      delete '/api/v1/profile/header', headers: headers

      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')

      account.reload
      expect(account.avatar).to exist
      expect(account.header).to_not exist
      expect(ActivityPub::UpdateDistributionWorker)
        .to have_enqueued_sidekiq_job(account.id)
    end
  end

  describe 'DELETE /api/v1/profile/background' do
    context 'with wrong scope' do
      before do
        delete '/api/v1/profile/background', headers: headers
      end

      it_behaves_like 'forbidden for wrong scope', 'read'
    end

    it 'returns http success, preserves the avatar and header, deletes the background' do
      delete '/api/v1/profile/background', headers: headers

      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')

      account.reload
      expect(account.avatar).to exist
      expect(account.header).to exist
      expect(account.profile_background).to_not exist
    end
  end
end
