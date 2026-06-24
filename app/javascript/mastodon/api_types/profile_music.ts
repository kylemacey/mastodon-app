export type ApiProfileMusicProvider = 'soundcloud' | 'spotify' | 'bandcamp';

export const ACTIVE_PROFILE_MUSIC_PROVIDERS: readonly ApiProfileMusicProvider[] =
  ['soundcloud'];

export const hasActiveProfileMusicProviders =
  ACTIVE_PROFILE_MUSIC_PROVIDERS.length > 0;

export const isActiveProfileMusicProvider = (
  provider: ApiProfileMusicProvider,
) => ACTIVE_PROFILE_MUSIC_PROVIDERS.includes(provider);

export interface ApiProfileMusicItemJSON {
  provider: ApiProfileMusicProvider;
  provider_id?: string;
  url: string;
  embed_url: string;
  title: string;
  artist: string;
  thumbnail_url?: string | null;
  featured: boolean;
}

export type ApiProfileMusicUpdateParams = Pick<
  ApiProfileMusicItemJSON,
  'provider' | 'url'
> &
  Partial<
    Pick<
      ApiProfileMusicItemJSON,
      'provider_id' | 'title' | 'artist' | 'thumbnail_url'
    >
  >;
