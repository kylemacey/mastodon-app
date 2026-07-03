import { useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import { openModal } from '@/mastodon/actions/modal';
import { Button } from '@/mastodon/components/button';
import { DisplayName } from '@/mastodon/components/display_name';
import { EmptyState } from '@/mastodon/components/empty_state';
import { LimitedAccountHint } from '@/mastodon/components/limited_account_hint';
import { useAccount } from '@/mastodon/hooks/useAccount';
import { useCurrentAccountId } from '@/mastodon/hooks/useAccountId';
import { useAppDispatch } from '@/mastodon/store';

interface EmptyMessageProps {
  suspended: boolean;
  hidden: boolean;
  blockedBy: boolean;
  accountId?: string;
  variant?: 'top8' | 'collections';
  withoutAddCollectionButton?: boolean;
}

export const EmptyMessage: React.FC<EmptyMessageProps> = ({
  accountId,
  suspended,
  hidden,
  blockedBy,
  variant = 'top8',
  withoutAddCollectionButton,
}) => {
  const me = useCurrentAccountId();
  const account = useAccount(accountId);

  const dispatch = useAppDispatch();

  const confirmHideFeaturedTab = useCallback(() => {
    void dispatch(
      openModal({
        modalType: 'ACCOUNT_HIDE_FEATURED_TAB',
        modalProps: {},
      }),
    );
  }, [dispatch]);

  if (!accountId) {
    return null;
  }

  let title: React.ReactNode = null;
  let message: React.ReactNode = null;

  if (variant === 'collections') {
    if (me === accountId) {
      title = (
        <FormattedMessage
          id='empty_column.account_featured_collections_self'
          defaultMessage='You have not created any collections yet.'
        />
      );
    } else if (account) {
      title = (
        <FormattedMessage
          id='empty_column.account_featured_collections.other'
          defaultMessage='{acct} has not created any collections yet.'
          values={{ acct: <DisplayName variant='simple' account={account} /> }}
        />
      );
    } else {
      title = (
        <FormattedMessage
          id='empty_column.account_featured_collections_unknown.other'
          defaultMessage='This account has not created any collections yet.'
        />
      );
    }
  } else if (me === accountId) {
    // Return only here to insert the "Create a collection" button as the action for the empty state.
    return (
      <EmptyState
        title={
          <FormattedMessage
            id='empty_column.account_featured_self.showcase_accounts'
            defaultMessage='Build your Top 8'
          />
        }
        message={
          <FormattedMessage
            id='empty_column.account_featured_self.showcase_accounts_desc'
            defaultMessage='Add favorite accounts from their profiles, then arrange them here.'
          />
        }
      >
        {!withoutAddCollectionButton && (
          <Link to='/collections/new' className='button'>
            <FormattedMessage
              id='empty_column.account_featured_self.no_collections_button'
              defaultMessage='Create a collection'
            />
          </Link>
        )}
        <Button secondary onClick={confirmHideFeaturedTab}>
          <FormattedMessage
            id='empty_column.account_featured_self.no_collections_hide_tab'
            defaultMessage='Hide My Top 8 instead'
          />
        </Button>
      </EmptyState>
    );
  } else if (suspended) {
    title = (
      <FormattedMessage
        id='empty_column.account_suspended'
        defaultMessage='Account suspended'
      />
    );
  } else if (hidden) {
    message = <LimitedAccountHint accountId={accountId} />;
  } else if (blockedBy) {
    title = (
      <FormattedMessage
        id='empty_column.account_unavailable'
        defaultMessage='Profile unavailable'
      />
    );
  } else {
    if (account) {
      title = (
        <FormattedMessage
          id='empty_column.account_featured.other'
          defaultMessage='{acct} has not added a Top 8 yet.'
          values={{ acct: <DisplayName variant='simple' account={account} /> }}
        />
      );
    } else {
      title = (
        <FormattedMessage
          id='empty_column.account_featured_unknown.other'
          defaultMessage='This account has not added a Top 8 yet.'
        />
      );
    }
  }

  return <EmptyState title={title} message={message} />;
};
