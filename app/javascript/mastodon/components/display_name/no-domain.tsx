import type { ComponentPropsWithoutRef, FC } from 'react';

import classNames from 'classnames';

import { AnimateEmojiProvider } from '../emoji/context';
import { EmojiHTML } from '../emoji/html';
import { Skeleton } from '../skeleton';

import type { DisplayNameProps } from './index';
import { profileFontClassName } from './profile_font';

export const DisplayNameWithoutDomain: FC<
  Omit<DisplayNameProps, 'variant'> & ComponentPropsWithoutRef<'span'>
> = ({ account, className, children, localDomain: _, ...props }) => {
  return (
    <AnimateEmojiProvider
      {...props}
      as='span'
      className={classNames(
        'display-name',
        profileFontClassName(account),
        className,
      )}
    >
      <bdi>
        {account ? (
          <EmojiHTML
            className='display-name__html'
            htmlString={account.display_name_html}
            as='strong'
            extraEmojis={account.emojis}
          />
        ) : (
          <strong className='display-name__html'>
            <Skeleton width='10ch' />
          </strong>
        )}
      </bdi>
      {children}
    </AnimateEmojiProvider>
  );
};
