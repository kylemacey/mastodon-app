import type { ChangeEventHandler, FC, KeyboardEventHandler } from 'react';
import { forwardRef, useCallback, useState } from 'react';

import { defineMessages, FormattedMessage, useIntl } from 'react-intl';

import AddIcon from '@/material-icons/400-24px/add.svg?react';
import ArrowDownwardIcon from '@/material-icons/400-24px/arrow_downward.svg?react';
import ArrowUpwardIcon from '@/material-icons/400-24px/arrow_upward.svg?react';
import DeleteIcon from '@/material-icons/400-24px/delete.svg?react';
import MusicNoteIcon from '@/material-icons/400-24px/music_note.svg?react';
import { Button } from '@/mastodon/components/button';
import { TextInputField } from '@/mastodon/components/form_fields';
import { Icon } from '@/mastodon/components/icon';
import { IconButton } from '@/mastodon/components/icon_button';
import {
  hasActiveProfileMusicProviders,
  isActiveProfileMusicProvider,
} from '@/mastodon/api_types/profile_music';
import type { ApiProfileMusicUpdateParams } from '@/mastodon/api_types/profile_music';
import {
  patchProfile,
  searchSoundcloudTracks,
} from '@/mastodon/reducers/slices/profile_edit';
import type {
  MusicData,
  ProfileEditState,
} from '@/mastodon/reducers/slices/profile_edit';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';
import { hashObjectArray } from '@/mastodon/utils/hash';

import type { DialogModalProps } from '../../ui/components/dialog_modal';
import { DialogModal } from '../../ui/components/dialog_modal';

import classes from './styles.module.scss';

const MAX_TRACKS = 5;

const messages = defineMessages({
  title: {
    id: 'account_edit.profile_music.title',
    defaultMessage: 'Profile music',
  },
  save: {
    id: 'account_edit.save',
    defaultMessage: 'Save',
  },
  soundcloudSearchLabel: {
    id: 'account_edit.profile_music.soundcloud_search',
    defaultMessage: 'Search SoundCloud',
  },
  soundcloudSearchButton: {
    id: 'account_edit.profile_music.soundcloud_search_button',
    defaultMessage: 'Search',
  },
  soundcloudUrlLabel: {
    id: 'account_edit.profile_music.soundcloud_url',
    defaultMessage: 'SoundCloud track URL',
  },
  addSoundcloud: {
    id: 'account_edit.profile_music.add_soundcloud',
    defaultMessage: 'Add SoundCloud track',
  },
  full: {
    id: 'account_edit.profile_music.full',
    defaultMessage: 'You can add up to five songs.',
  },
  searchUnavailable: {
    id: 'account_edit.profile_music.soundcloud_unavailable',
    defaultMessage: 'SoundCloud search is unavailable right now.',
  },
  saveError: {
    id: 'account_edit.profile_music.save_error',
    defaultMessage: 'One of these songs could not be saved.',
  },
  featured: {
    id: 'account_edit.profile_music.featured',
    defaultMessage: 'Featured',
  },
  addTrack: {
    id: 'account_edit.profile_music.add_track',
    defaultMessage: 'Add {title}',
  },
  removeTrack: {
    id: 'account_edit.profile_music.remove_track',
    defaultMessage: 'Remove {title}',
  },
  moveUp: {
    id: 'account_edit.profile_music.move_up',
    defaultMessage: 'Move {title} up',
  },
  moveDown: {
    id: 'account_edit.profile_music.move_down',
    defaultMessage: 'Move {title} down',
  },
});

export const MusicModal: FC<DialogModalProps> = forwardRef(
  ({ onClose }, _ref) => {
    void _ref;

    const { profile, isPending } = useAppSelector((state) => state.profileEdit);

    if (!hasActiveProfileMusicProviders || !profile) {
      return null;
    }

    return (
      <MusicModalContent
        key={profile.id}
        profile={profile}
        isPending={isPending}
        onClose={onClose}
      />
    );
  },
);
MusicModal.displayName = 'MusicModal';

const MusicModalContent: FC<
  DialogModalProps & {
    profile: NonNullable<ProfileEditState['profile']>;
    isPending: boolean;
  }
> = ({ profile, isPending, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();

  const [tracks, setTracks] = useState<MusicData[]>(
    profile.profileMusic.filter((track) =>
      isActiveProfileMusicProvider(track.provider),
    ),
  );
  const [soundcloudQuery, setSoundcloudQuery] = useState('');
  const [soundcloudResults, setSoundcloudResults] = useState<MusicData[]>([]);
  const [soundcloudUrl, setSoundcloudUrl] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [soundcloudError, setSoundcloudError] = useState('');
  const [saveError, setSaveError] = useState('');

  const full = tracks.length >= MAX_TRACKS;

  const handleSoundcloudQueryChange: ChangeEventHandler<HTMLInputElement> =
    useCallback((event) => {
      setSoundcloudQuery(event.currentTarget.value);
    }, []);

  const handleSoundcloudUrlChange: ChangeEventHandler<HTMLInputElement> =
    useCallback((event) => {
      setSoundcloudUrl(event.currentTarget.value);
    }, []);

  const handleSoundcloudSearch = useCallback(async () => {
    if (isPending || isSearching || full || !soundcloudQuery.trim()) {
      return;
    }

    setSoundcloudError('');
    setIsSearching(true);

    try {
      const results = await dispatch(
        searchSoundcloudTracks({ q: soundcloudQuery }),
      ).unwrap();
      setSoundcloudResults(hashObjectArray(results));
    } catch {
      setSoundcloudError(intl.formatMessage(messages.searchUnavailable));
    } finally {
      setIsSearching(false);
    }
  }, [dispatch, full, intl, isPending, isSearching, soundcloudQuery]);

  const handleSoundcloudSearchClick = useCallback(() => {
    void handleSoundcloudSearch();
  }, [handleSoundcloudSearch]);

  const handleSoundcloudSearchKeyDown: KeyboardEventHandler<HTMLInputElement> =
    useCallback(
      (event) => {
        if (event.key !== 'Enter') {
          return;
        }

        event.preventDefault();
        void handleSoundcloudSearch();
      },
      [handleSoundcloudSearch],
    );

  const addTrack = useCallback((track: MusicData) => {
    setTracks((previous) => {
      if (
        previous.length >= MAX_TRACKS ||
        previous.some((item) => item.url === track.url)
      ) {
        return previous;
      }

      return withFeatured([...previous, track]);
    });
  }, []);

  const handleAddSoundcloud = useCallback(() => {
    const url = soundcloudUrl.trim();
    if (!url) {
      return;
    }

    addTrack({
      id: `soundcloud:${url}`,
      provider: 'soundcloud',
      url,
      embed_url: '',
      title: 'SoundCloud track',
      artist: url,
      featured: tracks.length === 0,
    });
    setSoundcloudUrl('');
  }, [addTrack, soundcloudUrl, tracks.length]);

  const removeTrack = useCallback((track: MusicData) => {
    setTracks((previous) =>
      withFeatured(previous.filter((item) => item.id !== track.id)),
    );
  }, []);

  const moveTrack = useCallback((track: MusicData, direction: -1 | 1) => {
    setTracks((previous) => {
      const index = previous.findIndex((item) => item.id === track.id);
      const nextIndex = index + direction;
      if (index < 0 || nextIndex < 0 || nextIndex >= previous.length) {
        return previous;
      }

      const next = [...previous];
      const currentTrack = next[index];
      const targetTrack = next[nextIndex];
      if (!currentTrack || !targetTrack) {
        return previous;
      }

      next[index] = targetTrack;
      next[nextIndex] = currentTrack;
      return withFeatured(next);
    });
  }, []);

  const handleSave = useCallback(async () => {
    setSaveError('');

    try {
      await dispatch(
        patchProfile({
          profile_music: tracks.map(serializeTrack),
        }),
      ).unwrap();
      onClose();
    } catch {
      setSaveError(intl.formatMessage(messages.saveError));
    }
  }, [dispatch, intl, onClose, tracks]);

  const handleSaveClick = useCallback(() => {
    void handleSave();
  }, [handleSave]);

  return (
    <DialogModal
      onClose={onClose}
      title={intl.formatMessage(messages.title)}
      buttons={
        <Button onClick={handleSaveClick} disabled={isPending}>
          <FormattedMessage {...messages.save} />
        </Button>
      }
    >
      <div className={classes.profileMusicWrapper}>
        <div className={classes.profileMusicAddRow}>
          <TextInputField
            value={soundcloudQuery}
            onChange={handleSoundcloudQueryChange}
            onKeyDown={handleSoundcloudSearchKeyDown}
            disabled={isPending || full}
            enterKeyHint='search'
            label={<FormattedMessage {...messages.soundcloudSearchLabel} />}
          />
          <Button
            onClick={handleSoundcloudSearchClick}
            disabled={isPending || isSearching || full}
            loading={isSearching}
          >
            <FormattedMessage {...messages.soundcloudSearchButton} />
          </Button>
        </div>

        {soundcloudError && (
          <p className={classes.profileMusicError}>{soundcloudError}</p>
        )}

        {soundcloudResults.length > 0 && (
          <ol className={classes.profileMusicResults}>
            {soundcloudResults.map((track) => (
              <MusicResult
                key={track.id}
                track={track}
                disabled={
                  isPending ||
                  full ||
                  tracks.some((item) => item.url === track.url)
                }
                onAdd={addTrack}
              />
            ))}
          </ol>
        )}

        <div className={classes.profileMusicAddRow}>
          <TextInputField
            type='url'
            value={soundcloudUrl}
            onChange={handleSoundcloudUrlChange}
            disabled={isPending || full}
            label={<FormattedMessage {...messages.soundcloudUrlLabel} />}
            placeholder='https://soundcloud.com/odesza/line-of-sight-feat-wynne-mansionair'
          />
          <Button onClick={handleAddSoundcloud} disabled={isPending || full}>
            <FormattedMessage {...messages.addSoundcloud} />
          </Button>
        </div>

        {full && (
          <p className={classes.profileMusicHint}>
            <FormattedMessage {...messages.full} />
          </p>
        )}

        {saveError && (
          <p className={classes.profileMusicError}>{saveError}</p>
        )}

        <ol className={classes.profileMusicTracks}>
          {tracks.map((track, index) => (
            <MusicTrack
              key={track.id}
              track={track}
              index={index}
              tracksCount={tracks.length}
              isPending={isPending}
              onMove={moveTrack}
              onRemove={removeTrack}
            />
          ))}
        </ol>
      </div>
    </DialogModal>
  );
};

const MusicTrack: FC<{
  track: MusicData;
  index: number;
  tracksCount: number;
  isPending: boolean;
  onMove: (track: MusicData, direction: -1 | 1) => void;
  onRemove: (track: MusicData) => void;
}> = ({ track, index, tracksCount, isPending, onMove, onRemove }) => {
  const intl = useIntl();

  const handleMoveUp = useCallback(() => {
    onMove(track, -1);
  }, [onMove, track]);

  const handleMoveDown = useCallback(() => {
    onMove(track, 1);
  }, [onMove, track]);

  const handleRemove = useCallback(() => {
    onRemove(track);
  }, [onRemove, track]);

  return (
    <li className={classes.profileMusicTrack}>
      <MusicArtwork track={track} />
      <span>
        <strong>{track.title}</strong>
        {track.artist && <small>{track.artist}</small>}
        {index === 0 && (
          <em>
            <FormattedMessage {...messages.featured} />
          </em>
        )}
      </span>
      <div className={classes.profileMusicTrackActions}>
        <IconButton
          icon='arrow-upward'
          iconComponent={ArrowUpwardIcon}
          title={intl.formatMessage(messages.moveUp, {
            title: track.title,
          })}
          onClick={handleMoveUp}
          disabled={isPending || index === 0}
        />
        <IconButton
          icon='arrow-downward'
          iconComponent={ArrowDownwardIcon}
          title={intl.formatMessage(messages.moveDown, {
            title: track.title,
          })}
          onClick={handleMoveDown}
          disabled={isPending || index === tracksCount - 1}
        />
        <IconButton
          icon='delete'
          iconComponent={DeleteIcon}
          title={intl.formatMessage(messages.removeTrack, {
            title: track.title,
          })}
          onClick={handleRemove}
          disabled={isPending}
        />
      </div>
    </li>
  );
};

const MusicResult: FC<{
  track: MusicData;
  disabled: boolean;
  onAdd: (track: MusicData) => void;
}> = ({ track, disabled, onAdd }) => {
  const intl = useIntl();

  const handleAdd = useCallback(() => {
    onAdd(track);
  }, [onAdd, track]);

  return (
    <li className={classes.profileMusicResult}>
      <MusicArtwork track={track} />
      <span>
        <strong>{track.title}</strong>
        {track.artist && <small>{track.artist}</small>}
      </span>
      <IconButton
        icon='add'
        iconComponent={AddIcon}
        title={intl.formatMessage(messages.addTrack, { title: track.title })}
        disabled={disabled}
        onClick={handleAdd}
      />
    </li>
  );
};

const MusicArtwork: FC<{ track: MusicData }> = ({ track }) => {
  if (track.thumbnail_url) {
    return (
      <img
        className={classes.profileMusicArtwork}
        src={track.thumbnail_url}
        alt=''
      />
    );
  }

  return (
    <span className={classes.profileMusicArtwork} aria-hidden='true'>
      <Icon id='music-note' icon={MusicNoteIcon} />
    </span>
  );
};

const serializeTrack = (track: MusicData): ApiProfileMusicUpdateParams => ({
  provider: track.provider,
  provider_id: track.provider_id,
  url: track.url,
  title: track.title,
  artist: track.artist,
  thumbnail_url: track.thumbnail_url,
});

const withFeatured = (tracks: MusicData[]) =>
  tracks.map((track, index) => ({ ...track, featured: index === 0 }));
