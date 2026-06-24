import type { ApiAccountFieldJSON } from './accounts';
import type {
  ApiProfileMusicItemJSON,
  ApiProfileMusicUpdateParams,
} from './profile_music';
import type { ApiProfileFont } from './profile_theme';
import type { ApiFeaturedTagJSON } from './tags';

export interface ApiProfileJSON {
  id: string;
  display_name: string;
  note: string;
  fields: ApiAccountFieldJSON[];
  avatar: string;
  avatar_static: string;
  avatar_description: string;
  header: string;
  header_static: string;
  header_description: string;
  profile_background: string | null;
  profile_background_static: string | null;
  profile_background_color: string;
  profile_accent_color: string;
  profile_font: ApiProfileFont;
  profile_custom_css: string;
  profile_music: ApiProfileMusicItemJSON[];
  locked: boolean;
  bot: boolean;
  hide_collections: boolean;
  discoverable: boolean;
  indexable: boolean;
  show_media: boolean;
  show_media_replies: boolean;
  show_featured: boolean;
  attribution_domains: string[];
  featured_tags: ApiFeaturedTagJSON[];
}

export type ApiProfileUpdateParams = Partial<
  Pick<
    ApiProfileJSON,
    | 'avatar_description'
    | 'header_description'
    | 'profile_background_color'
    | 'profile_accent_color'
    | 'profile_font'
    | 'profile_custom_css'
    | 'display_name'
    | 'note'
    | 'locked'
    | 'bot'
    | 'hide_collections'
    | 'discoverable'
    | 'indexable'
    | 'show_media'
    | 'show_media_replies'
    | 'show_featured'
  >
> & {
  attribution_domains?: string[];
  fields_attributes?: Pick<ApiAccountFieldJSON, 'name' | 'value'>[];
  profile_music?: ApiProfileMusicUpdateParams[];
};
