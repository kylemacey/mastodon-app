import type { Account, AccountShapeFull } from '@/mastodon/models/account';

export function profileFontClassName(account?: Account | AccountShapeFull) {
  const font = account?.profile_font ?? 'system';
  return font === 'system' ? undefined : `profile-font--${font}`;
}
