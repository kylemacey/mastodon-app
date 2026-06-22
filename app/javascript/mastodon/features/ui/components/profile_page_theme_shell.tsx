import { forwardRef, useEffect, useMemo } from 'react';
import type { CSSProperties, ReactNode } from 'react';

import classNames from 'classnames';
import { matchPath } from 'react-router-dom';

import { fetchAccount, lookupAccount } from 'mastodon/actions/accounts';
import { normalizeForLookup } from 'mastodon/reducers/accounts_map';
import {
  fetchProfileTheme,
  selectProfileTheme,
} from 'mastodon/reducers/slices/profile_theme';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import classes from './profile_page_theme_shell.module.scss';

interface ProfilePageThemeShellProps {
  children: ReactNode;
  className?: string;
  location: {
    pathname: string;
  };
}

interface ProfileRouteParams {
  acct?: string;
  id?: string;
}

const profileRouteMatchers = [
  { path: ['/@:acct', '/accounts/:id'], exact: true },
  { path: ['/@:acct/featured', '/accounts/:id/featured'] },
  { path: ['/@:acct/collections'] },
  { path: ['/@:acct/tagged/:tagged?'], exact: true },
  { path: ['/@:acct/with_replies', '/accounts/:id/with_replies'] },
  {
    path: [
      '/accounts/:id/followers',
      '/users/:acct/followers',
      '/@:acct/followers',
    ],
  },
  {
    path: [
      '/accounts/:id/following',
      '/users/:acct/following',
      '/@:acct/following',
    ],
  },
  { path: ['/@:acct/media', '/accounts/:id/media'] },
];

const getProfileRouteParams = (pathname: string) => {
  for (const matcher of profileRouteMatchers) {
    const match = matchPath<ProfileRouteParams>(pathname, matcher);

    if (match) {
      return match.params;
    }
  }

  return undefined;
};

export const ProfilePageThemeShell = forwardRef<
  HTMLDivElement,
  ProfilePageThemeShellProps
>(({ children, className, location }, ref) => {
  const dispatch = useAppDispatch();
  const params = useMemo(
    () => getProfileRouteParams(location.pathname),
    [location.pathname],
  );
  const accountId = useAppSelector((state) => {
    if (params?.id) {
      return params.id;
    }

    if (params?.acct) {
      return state.accounts_map[normalizeForLookup(params.acct)];
    }

    return undefined;
  });
  const account = useAppSelector((state) =>
    accountId ? state.accounts.get(accountId) : undefined,
  );
  const theme = useAppSelector((state) =>
    accountId ? selectProfileTheme(state, accountId) : undefined,
  );
  const customProperties: CSSProperties & Record<string, string> = {};

  useEffect(() => {
    if (typeof accountId === 'undefined' && params?.acct) {
      dispatch(lookupAccount(params.acct));
    } else if (accountId && !account) {
      dispatch(fetchAccount(accountId));
    }
  }, [account, accountId, dispatch, params?.acct]);

  useEffect(() => {
    if (accountId) {
      void dispatch(fetchProfileTheme({ accountId }));
    }
  }, [accountId, dispatch]);

  if (theme?.profile_background_color) {
    customProperties['--profile-background-color'] =
      theme.profile_background_color;
    customProperties['--profile-theme-background-color'] =
      theme.profile_background_color;
  }

  if (theme?.profile_accent_color) {
    customProperties['--profile-accent-color'] = theme.profile_accent_color;
    customProperties['--profile-theme-accent'] = theme.profile_accent_color;
  }

  if (theme?.profile_background_static) {
    customProperties['--profile-background-image'] =
      `url("${theme.profile_background_static}")`;
    customProperties['--profile-theme-background-image'] =
      `url("${theme.profile_background_static}")`;
  }

  const nonce = document.querySelector<HTMLMetaElement>(
    'meta[name=style-nonce]',
  )?.content;

  return (
    <div
      ref={ref}
      id={theme?.profile_dom_id}
      data-profile-theme-account-id={accountId}
      className={classNames(
        className,
        classes.profileThemeRoot,
        theme?.profile_accent_color && classes.profileThemeRootAccent,
        Boolean(theme?.profile_background_color ?? theme?.profile_background) &&
          classes.profileThemeRootBackground,
      )}
      style={customProperties}
    >
      {theme?.profile_custom_css && (
        <style
          nonce={nonce}
          dangerouslySetInnerHTML={{ __html: theme.profile_custom_css }}
        />
      )}
      {children}
    </div>
  );
});

ProfilePageThemeShell.displayName = 'ProfilePageThemeShell';
