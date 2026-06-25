import { useCallback, useEffect, useMemo } from 'react';

import { defineMessages, FormattedMessage, useIntl } from 'react-intl';

import { Link } from 'react-router-dom';

import { List as ImmutableList } from 'immutable';

import type {
  Announcements,
  DragEndEvent,
  ScreenReaderInstructions,
} from '@dnd-kit/core';
import {
  closestCenter,
  DndContext,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core';
import {
  arrayMove,
  rectSortingStrategy,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

import {
  fetchEndorsedAccounts,
  reorderEndorsedAccounts,
} from '@/mastodon/actions/accounts';
import { Avatar } from '@/mastodon/components/avatar';
import { Icon } from '@/mastodon/components/icon';
import { useAccount } from '@/mastodon/hooks/useAccount';
import { me } from '@/mastodon/initial_state';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';
import DragIndicatorIcon from '@/material-icons/400-24px/drag_indicator.svg?react';

import classes from './styles.module.scss';

const messages = defineMessages({
  top8: {
    id: 'account.featured.top_8',
    defaultMessage: 'Top 8',
  },
  myTop8: {
    id: 'account.featured.my_top_8',
    defaultMessage: 'My Top 8',
  },
  dragHandle: {
    id: 'account.featured.top_8.drag_handle',
    defaultMessage: 'Drag #{position} in your Top 8',
  },
  screenReaderInstructions: {
    id: 'account.featured.top_8.drag_instructions',
    defaultMessage:
      'To rearrange your Top 8, press space or enter. While dragging, use the arrow keys to move the account. Press space or enter again to drop it in its new position, or press escape to cancel.',
  },
  onDragStart: {
    id: 'account.featured.top_8.drag_start',
    defaultMessage: 'Picked up account {item}.',
  },
  onDragOver: {
    id: 'account.featured.top_8.drag_over',
    defaultMessage: 'Account {item} was moved.',
  },
  onDragEnd: {
    id: 'account.featured.top_8.drag_end',
    defaultMessage: 'Account {item} was dropped.',
  },
  onDragCancel: {
    id: 'account.featured.top_8.drag_cancel',
    defaultMessage: 'Dragging was cancelled. Account {item} was dropped.',
  },
});

export const AccountTop8: React.FC<{
  accountId: string;
  hidden?: boolean;
}> = ({ accountId, hidden }) => {
  const account = useAccount(accountId);
  const dispatch = useAppDispatch();
  const isOwnProfile = accountId === me;

  useEffect(() => {
    if (account?.show_featured && !hidden) {
      void dispatch(fetchEndorsedAccounts({ accountId }));
    }
  }, [account?.show_featured, accountId, dispatch, hidden]);

  const featuredAccountIds = useAppSelector(
    (state) =>
      state.user_lists.getIn(
        ['featured_accounts', accountId, 'items'],
        ImmutableList(),
      ) as ImmutableList<string>,
  );

  const accountIds = useMemo(
    () => featuredAccountIds.toArray(),
    [featuredAccountIds],
  );

  if (!account?.show_featured || hidden || accountIds.length === 0) {
    return null;
  }

  return (
    <section className={classes.top8Panel} aria-labelledby='account-top-8'>
      <h2 className={classes.top8Title} id='account-top-8'>
        <FormattedMessage
          {...(isOwnProfile ? messages.myTop8 : messages.top8)}
        />
      </h2>
      <Top8AccountList
        accountIds={accountIds}
        isOwnProfile={isOwnProfile}
        ownerAccountId={accountId}
      />
    </section>
  );
};

const Top8AccountList: React.FC<{
  accountIds: string[];
  isOwnProfile: boolean;
  ownerAccountId: string;
}> = ({ accountIds, isOwnProfile, ownerAccountId }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 5,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  const accessibility: {
    screenReaderInstructions: ScreenReaderInstructions;
    announcements: Announcements;
  } = useMemo(
    () => ({
      screenReaderInstructions: {
        draggable: intl.formatMessage(messages.screenReaderInstructions),
      },
      announcements: {
        onDragStart({ active }) {
          return intl.formatMessage(messages.onDragStart, { item: active.id });
        },
        onDragOver({ active }) {
          return intl.formatMessage(messages.onDragOver, { item: active.id });
        },
        onDragEnd({ active }) {
          return intl.formatMessage(messages.onDragEnd, { item: active.id });
        },
        onDragCancel({ active }) {
          return intl.formatMessage(messages.onDragCancel, { item: active.id });
        },
      },
    }),
    [intl],
  );

  const handleDragEnd = useCallback(
    ({ active, over }: DragEndEvent) => {
      if (!over || active.id === over.id) {
        return;
      }

      const oldIndex = accountIds.indexOf(active.id as string);
      const newIndex = accountIds.indexOf(over.id as string);

      if (oldIndex === -1 || newIndex === -1) {
        return;
      }

      void dispatch(
        reorderEndorsedAccounts({
          accountId: ownerAccountId,
          accountIds: arrayMove(accountIds, oldIndex, newIndex),
        }),
      );
    },
    [accountIds, dispatch, ownerAccountId],
  );

  return (
    <DndContext
      accessibility={accessibility}
      collisionDetection={closestCenter}
      onDragEnd={handleDragEnd}
      sensors={sensors}
    >
      <SortableContext items={accountIds} strategy={rectSortingStrategy}>
        <ol className={classes.top8List}>
          {accountIds.map((featuredAccountId, index) => (
            <Top8AccountItem
              accountId={featuredAccountId}
              index={index}
              isOwnProfile={isOwnProfile}
              key={featuredAccountId}
            />
          ))}
        </ol>
      </SortableContext>
    </DndContext>
  );
};

const Top8AccountItem: React.FC<{
  accountId: string;
  index: number;
  isOwnProfile: boolean;
}> = ({ accountId, index, isOwnProfile }) => {
  const intl = useIntl();
  const account = useAccount(accountId);
  const {
    attributes,
    listeners,
    setActivatorNodeRef,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: accountId, disabled: !isOwnProfile });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  const renderButton = useCallback(() => {
    if (!isOwnProfile) {
      return null;
    }

    return (
      <button
        {...attributes}
        {...listeners}
        aria-label={intl.formatMessage(messages.dragHandle, {
          position: index + 1,
        })}
        className={classes.top8DragHandle}
        ref={setActivatorNodeRef}
        type='button'
      >
        <Icon id='drag-indicator' icon={DragIndicatorIcon} />
      </button>
    );
  }, [attributes, index, intl, isOwnProfile, listeners, setActivatorNodeRef]);

  const displayName = account?.display_name.trim()
    ? account.display_name
    : account?.username;
  const acct = account?.acct;
  const label = `${index + 1}. ${displayName}${acct ? `, @${acct}` : ''}`;

  return (
    <li
      className={classes.top8Item}
      data-dragging={isDragging}
      ref={setNodeRef}
      style={style}
    >
      <span className={classes.top8Rank}>{index + 1}</span>
      {account ? (
        <Link
          aria-label={label}
          className={classes.top8AvatarLink}
          data-hover-card-account={account.id}
          data-tooltip={displayName}
          title={label}
          to={`/@${account.acct}`}
        >
          <Avatar account={account} alt='' size={64} />
        </Link>
      ) : (
        <span className={classes.top8AvatarPlaceholder} aria-hidden />
      )}
      {renderButton()}
    </li>
  );
};
