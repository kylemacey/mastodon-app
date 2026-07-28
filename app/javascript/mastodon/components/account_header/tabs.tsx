import { useEffect } from 'react';
import type { FC } from 'react';

import { FormattedMessage } from 'react-intl';

import type { NavLinkProps } from 'react-router-dom';

import { useAccount } from '@/mastodon/hooks/useAccount';
import { useAccountId } from '@/mastodon/hooks/useAccountId';
import {
  fetchCollectionsCreatedByAccount,
  selectAccountCollections,
} from '@/mastodon/reducers/slices/collections';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';

import { TabLink, TabList } from '../tab_list';

import classes from './styles.module.scss';

const isActive: Required<NavLinkProps>['isActive'] = (match, location) =>
  match?.url === location.pathname ||
  (!!match?.url && location.pathname.startsWith(`${match.url}/tagged/`));

export const AccountTabs: FC = () => {
  const accountId = useAccountId();
  const account = useAccount(accountId);
  const dispatch = useAppDispatch();
  const { collections, status } = useAppSelector((state) =>
    selectAccountCollections(state, accountId, 'createdBy'),
  );

  useEffect(() => {
    if (accountId && account?.show_featured) {
      void dispatch(fetchCollectionsCreatedByAccount({ accountId }));
    }
  }, [account?.show_featured, accountId, dispatch]);

  if (!account) {
    return <hr className={classes.noTabs} />;
  }

  const { acct, show_featured, show_media } = account;
  const showCollections =
    show_featured && status === 'idle' && collections.length > 0;

  if (!showCollections && !show_media) {
    return <hr className={classes.noTabs} />;
  }

  return (
    <TabList>
      <TabLink isActive={isActive} to={`/@${acct}`}>
        <FormattedMessage id='account.activity' defaultMessage='Activity' />
      </TabLink>
      {show_media && (
        <TabLink exact to={`/@${acct}/media`}>
          <FormattedMessage id='account.media' defaultMessage='Media' />
        </TabLink>
      )}
      {showCollections && (
        <TabLink exact to={`/@${acct}/featured`}>
          <FormattedMessage
            id='account.featured.collections'
            defaultMessage='Collections'
          />
        </TabLink>
      )}
    </TabList>
  );
};
