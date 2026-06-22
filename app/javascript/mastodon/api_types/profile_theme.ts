export type ApiProfileFont = 'system' | 'sans' | 'serif' | 'mono' | 'pixel';

export interface ApiProfileThemeJSON {
  id: string;
  profile_dom_id: string;
  profile_background: string | null;
  profile_background_static: string | null;
  profile_background_color: string;
  profile_accent_color: string;
  profile_font: ApiProfileFont;
  profile_custom_css: string;
}
