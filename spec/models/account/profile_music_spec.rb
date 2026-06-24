# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, '#profile_music' do
  let(:spotify_id) { '3n3Ppam7vgaVa1iaRUc9Lp' }
  let(:spotify_url) { "https://open.spotify.com/track/#{spotify_id}?si=abc123" }
  let(:bandcamp_url) { 'https://pinegrove.bandcamp.com/track/aphasia' }
  let(:soundcloud_url) { 'https://soundcloud.com/odesza/line-of-sight-feat-wynne-mansionair' }

  describe 'normalization' do
    it 'normalizes Spotify track URLs without exposing inactive providers publicly' do
      account = Fabricate.build(:account, profile_music: [{ url: spotify_url, title: 'A Song', artist: 'The Band' }])

      expect(account).to be_valid
      expect(account.profile_music).to contain_exactly(
        include(
          'provider' => 'spotify',
          'provider_id' => spotify_id,
          'url' => "https://open.spotify.com/track/#{spotify_id}",
          'embed_url' => "https://open.spotify.com/embed/track/#{spotify_id}",
          'title' => 'A Song',
          'artist' => 'The Band'
        )
      )
      expect(account.public_profile_music).to be_empty
    end

    it 'caps the playlist at five songs' do
      songs = Array.new(6) do |index|
        {
          provider: 'spotify',
          provider_id: format('%022d', index),
          title: "Song #{index}",
        }
      end

      account = Fabricate.build(
        :account,
        profile_music: [
          { url: '' },
          *songs,
        ]
      )

      expect(account).to be_valid
      expect(account.profile_music.size).to eq 5
    end

    it 'removes blank entries' do
      account = Fabricate.build(:account, profile_music: [{ url: '' }, { url: spotify_url }])

      expect(account).to be_valid
      expect(account.profile_music.size).to eq 1
    end

    it 'rejects unsupported providers' do
      account = Fabricate.build(:account, profile_music: [{ url: 'https://example.com/track/nope' }])

      expect(account).to_not be_valid
      expect(account.errors[:profile_music]).to include('contains an unsupported music link')
    end

    it 'resolves Bandcamp track URLs' do
      stub_bandcamp_track

      account = Fabricate.build(:account, profile_music: [{ url: bandcamp_url }])

      expect(account).to be_valid
      expect(account.profile_music.first)
        .to include(
          'provider' => 'bandcamp',
          'provider_id' => '1451517793',
          'url' => bandcamp_url,
          'embed_url' => bandcamp_embed_url,
          'title' => 'Aphasia',
          'artist' => 'Pinegrove',
          'thumbnail_url' => 'https://f4.bcbits.com/img/a0463988403_10.jpg'
        )
    end

    it 'cleans common Bandcamp mojibake from stored text metadata' do
      account = Fabricate.build(
        :account,
        profile_music: [
          {
            provider: 'bandcamp',
            provider_id: '193201886',
            url: 'https://spanishlovesongs.bandcamp.com/track/cocaine-lexapro-ft-kevin-devine',
            title: "Cocaine & Lexapro\u00c2 (ft. Kevin Devine)",
            artist: 'Spanish Love Songs',
          },
        ]
      )

      expect(account.profile_music.first)
        .to include('title' => 'Cocaine & Lexapro (ft. Kevin Devine)')
    end

    it 'resolves SoundCloud track URLs and exposes them publicly' do
      stub_soundcloud_track

      account = Fabricate.build(:account, profile_music: [{ url: soundcloud_url }])

      expect(account).to be_valid
      expect(account.profile_music.first)
        .to include(
          'provider' => 'soundcloud',
          'provider_id' => '319412512',
          'url' => soundcloud_url,
          'embed_url' => 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F319412512',
          'title' => 'Line Of Sight (feat. WYNNE & Mansionair)',
          'artist' => 'ODESZA',
          'thumbnail_url' => 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg'
        )
      expect(account.public_profile_music).to contain_exactly(
        include(
          'provider' => 'soundcloud',
          'provider_id' => '319412512',
          'featured' => true
        )
      )
    end

    it 'preserves SoundCloud metadata from selected search results' do
      account = Fabricate.build(
        :account,
        profile_music: [
          {
            provider: 'soundcloud',
            provider_id: '319412512',
            url: soundcloud_url,
            title: 'Line Of Sight (feat. WYNNE & Mansionair)',
            artist: 'ODESZA',
            thumbnail_url: 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg',
          },
        ]
      )

      expect(account).to be_valid
      expect(account.profile_music.first)
        .to include(
          'provider' => 'soundcloud',
          'provider_id' => '319412512',
          'artist' => 'ODESZA',
          'thumbnail_url' => 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg'
        )
    end

    it 'resolves SoundCloud track URLs through the API when configured' do
      Rails.cache.delete(ProfileMusic::SoundcloudSearchService::CACHE_KEY)

      ClimateControl.modify SOUNDCLOUD_CLIENT_ID: 'client', SOUNDCLOUD_CLIENT_SECRET: 'secret' do
        stub_soundcloud_token
        stub_request(:get, 'https://api.soundcloud.com/resolve')
          .with(query: { url: soundcloud_url })
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.dump(
              id: 319_412_512,
              access: 'playable',
              title: 'Line Of Sight (feat. WYNNE & Mansionair)',
              permalink_url: soundcloud_url,
              artwork_url: 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg',
              user: { username: 'ODESZA' }
            )
          )

        account = Fabricate.build(:account, profile_music: [{ url: soundcloud_url }])

        expect(account).to be_valid
        expect(account.profile_music.first)
          .to include(
            'provider' => 'soundcloud',
            'provider_id' => '319412512',
            'artist' => 'ODESZA',
            'thumbnail_url' => 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg'
          )
      end
    end

    it 'rejects SoundCloud URL-pasted tracks that only allow previews' do
      Rails.cache.delete(ProfileMusic::SoundcloudSearchService::CACHE_KEY)

      ClimateControl.modify SOUNDCLOUD_CLIENT_ID: 'client', SOUNDCLOUD_CLIENT_SECRET: 'secret' do
        stub_soundcloud_token
        stub_request(:get, 'https://api.soundcloud.com/resolve')
          .with(query: { url: soundcloud_url })
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.dump(
              id: 319_412_512,
              access: 'preview',
              title: 'Line Of Sight (feat. WYNNE & Mansionair)',
              permalink_url: soundcloud_url,
              artwork_url: 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg',
              user: { username: 'ODESZA' }
            )
          )

        account = Fabricate.build(:account, profile_music: [{ url: soundcloud_url }])

        expect(account).to_not be_valid
        expect(account.errors[:profile_music]).to include('contains a music link that could not be resolved')
      end
    end
  end

  def stub_bandcamp_track
    stub_request(:get, bandcamp_url)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'text/html; charset=utf-8' },
        body: <<~HTML
          <!doctype html>
          <html>
            <head>
              <meta
                name="bc-page-properties"
                content="{&quot;item_type&quot;:&quot;t&quot;,&quot;item_id&quot;:1451517793}">
              <meta property="og:title" content="Aphasia, by Pinegrove">
              <meta property="og:image" content="https://f4.bcbits.com/img/a0463988403_5.jpg">
              <script type="application/ld+json">
                {
                  "@type": "MusicRecording",
                  "name": "Aphasia",
                  "image": "https://f4.bcbits.com/img/a0463988403_10.jpg",
                  "additionalProperty": [
                    { "@type": "PropertyValue", "name": "track_id", "value": 1451517793 }
                  ],
                  "byArtist": { "@type": "MusicGroup", "name": "Pinegrove" }
                }
              </script>
            </head>
          </html>
        HTML
      )
  end

  def bandcamp_embed_url
    [
      'https://bandcamp.com/EmbeddedPlayer/track=1451517793',
      'size=small',
      'bgcol=ffffff',
      'linkcol=0687f5',
      'transparent=true',
      '',
    ].join('/')
  end

  def stub_soundcloud_track
    stub_request(:get, 'https://soundcloud.com/oembed')
      .with(query: { format: 'json', url: soundcloud_url })
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json; charset=utf-8' },
        body: JSON.dump(
          title: 'Line Of Sight (feat. WYNNE & Mansionair) by ODESZA',
          author_name: 'ODESZA',
          thumbnail_url: 'https://i1.sndcdn.com/artworks-TfZFt5fZdHtv-0-t500x500.jpg',
          html: '<iframe src="https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F319412512&show_artwork=true"></iframe>'
        )
      )
  end

  def stub_soundcloud_token
    stub_request(:post, 'https://secure.soundcloud.com/oauth/token')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: JSON.dump(access_token: 'token', expires_in: 3600)
      )
  end
end
