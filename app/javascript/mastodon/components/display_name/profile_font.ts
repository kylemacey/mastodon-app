import type { Account } from '@/mastodon/models/account';

export function profileFontClassName(account?: Account) {
  const font = account?.get('profile_font') ?? 'system';
  return font === 'system' ? undefined : `profile-font--${font}`;
}
