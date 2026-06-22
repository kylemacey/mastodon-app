import type { ComponentPropsWithoutRef, FC } from 'react';

import classNames from 'classnames';

import { EmojiHTML } from '../emoji/html';

import type { DisplayNameProps } from './index';
import { profileFontClassName } from './profile_font';

export const DisplayNameSimple: FC<
  Omit<DisplayNameProps, 'variant'> & ComponentPropsWithoutRef<'span'>
> = ({ account, className, localDomain: _, ...props }) => {
  if (!account) {
    return null;
  }

  return (
    <bdi>
      <EmojiHTML
        {...props}
        as='span'
        className={classNames(profileFontClassName(account), className)}
        htmlString={account.get('display_name_html')}
        extraEmojis={account.get('emojis')}
      />
    </bdi>
  );
};
