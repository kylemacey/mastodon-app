import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import classNames from 'classnames';

import MusicNoteIcon from '@/material-icons/400-24px/music_note.svg?react';
import { isActiveProfileMusicProvider } from '@/mastodon/api_types/profile_music';
import type { ApiProfileMusicItemJSON } from '@/mastodon/api_types/profile_music';
import { Icon } from '@/mastodon/components/icon';
import { useAppSelector } from '@/mastodon/store';

import classes from './styles.module.scss';

const SOUNDCLOUD_WIDGET_API = 'https://w.soundcloud.com/player/api.js';

interface SoundcloudWidget {
  bind: (eventName: string, listener: () => void) => void;
  unbind: (eventName: string) => void;
  load: (
    url: string,
    options: Record<string, string | boolean | (() => void)>,
  ) => void;
  play: () => void;
}

interface SoundcloudWidgetConstructor {
  (iframe: HTMLIFrameElement | string): SoundcloudWidget;
  Events: {
    FINISH: string;
    PLAY: string;
    READY: string;
  };
}

declare global {
  interface Window {
    SC?: {
      Widget: SoundcloudWidgetConstructor;
    };
  }
}

let soundcloudWidgetApiPromise: Promise<void> | undefined;

const iframeTitle = (track: ApiProfileMusicItemJSON) =>
  track.artist ? `${track.title} by ${track.artist}` : track.title;

export const AccountMusic: React.FC<{ accountId: string }> = ({
  accountId,
}) => {
  const profileMusic = useAppSelector(
    (state) => state.accounts.get(accountId)?.profile_music ?? [],
  );
  const music = useMemo(
    () =>
      profileMusic.filter((track) =>
        isActiveProfileMusicProvider(track.provider),
      ),
    [profileMusic],
  );
  const [selectedUrl, setSelectedUrl] = useState<string | undefined>();
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const loadedUrlRef = useRef<string>();
  const widgetRef = useRef<SoundcloudWidget>();
  const musicRef = useRef(music);
  const pendingAutoplayUrlRef = useRef<string>();
  const selectedUrlRef = useRef<string | undefined>();

  const selectedTrack = useMemo(
    () => music.find((track) => track.url === selectedUrl) ?? music[0],
    [music, selectedUrl],
  );
  const initialTrack = music[0];

  useEffect(() => {
    musicRef.current = music;
    selectedUrlRef.current = selectedTrack?.url;
  }, [music, selectedTrack?.url]);

  const playTrack = useCallback((track: ApiProfileMusicItemJSON) => {
    pendingAutoplayUrlRef.current = track.url;
    selectedUrlRef.current = track.url;

    setSelectedUrl(track.url);
    loadSoundcloudTrack(
      widgetRef.current,
      track,
      pendingAutoplayUrlRef,
      loadedUrlRef,
    );
  }, []);

  useEffect(() => {
    if (!initialTrack) {
      return;
    }

    let cancelled = false;

    const bindWidget = async () => {
      await loadSoundcloudWidgetApi();

      if (cancelled || !iframeRef.current || !window.SC) {
        return;
      }

      const widget = window.SC.Widget(iframeRef.current);
      const finishEvent = window.SC.Widget.Events.FINISH;
      loadedUrlRef.current = initialTrack.url;
      widgetRef.current = widget;

      widget.bind(window.SC.Widget.Events.READY, () => {
        const pendingUrl = pendingAutoplayUrlRef.current;
        const pendingTrack = musicRef.current.find(
          (track) => track.url === pendingUrl,
        );

        if (!pendingUrl || !pendingTrack) {
          return;
        }

        if (loadedUrlRef.current === pendingUrl) {
          widget.play();
        } else {
          loadSoundcloudTrack(
            widget,
            pendingTrack,
            pendingAutoplayUrlRef,
            loadedUrlRef,
          );
        }
      });

      widget.bind(window.SC.Widget.Events.PLAY, () => {
        pendingAutoplayUrlRef.current = undefined;
      });

      widget.bind(finishEvent, () => {
        const currentMusic = musicRef.current;
        const currentIndex = currentMusic.findIndex(
          (track) => track.url === selectedUrlRef.current,
        );
        const nextTrack = currentMusic[currentIndex + 1];

        if (nextTrack) {
          playTrack(nextTrack);
        }
      });
    };

    void bindWidget();

    return () => {
      cancelled = true;
      widgetRef.current = undefined;
    };
  }, [initialTrack, playTrack]);

  if (!initialTrack || !selectedTrack) {
    return null;
  }

  return (
    <section className={classes.music} aria-label='Profile music'>
      <iframe
        ref={iframeRef}
        className={classes.musicEmbed}
        title={iframeTitle(selectedTrack)}
        src={soundcloudEmbedUrl(initialTrack, true)}
        loading='eager'
        allow='autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture'
        sandbox='allow-forms allow-popups allow-popups-to-escape-sandbox allow-same-origin allow-scripts'
      />

      {music.length > 1 && (
        <ol className={classes.musicList}>
          {music.map((track) => (
            <MusicListItem
              key={track.url}
              track={track}
              selected={track.url === selectedTrack.url}
              onSelect={playTrack}
            />
          ))}
        </ol>
      )}
    </section>
  );
};

const MusicListItem: React.FC<{
  track: ApiProfileMusicItemJSON;
  selected: boolean;
  onSelect: (track: ApiProfileMusicItemJSON) => void;
}> = ({ track, selected, onSelect }) => {
  const handleClick = useCallback(() => {
    onSelect(track);
  }, [onSelect, track]);

  return (
    <li>
      <button
        type='button'
        className={classNames(
          classes.musicListItem,
          selected && classes.musicListItemActive,
        )}
        onClick={handleClick}
      >
        <MusicArtwork track={track} />
        <span className={classes.musicListText}>
          <strong>{track.title}</strong>
          {track.artist && <small>{track.artist}</small>}
        </span>
      </button>
    </li>
  );
};

const MusicArtwork: React.FC<{ track: ApiProfileMusicItemJSON }> = ({
  track,
}) => (
  <span className={classes.musicArtwork} aria-hidden='true'>
    {track.thumbnail_url ? (
      <img src={track.thumbnail_url} alt='' loading='lazy' />
    ) : (
      <Icon id='music-note' icon={MusicNoteIcon} />
    )}
  </span>
);

const soundcloudWidgetOptions = {
  buying: false,
  download: false,
  hide_related: true,
  liking: false,
  sharing: false,
  show_artwork: true,
  show_comments: false,
  show_playcount: false,
  show_reposts: false,
  show_teaser: false,
  show_user: true,
  single_active: true,
  visual: false,
};

const soundcloudEmbedUrl = (
  track: ApiProfileMusicItemJSON,
  autoPlay: boolean,
) => {
  const url = new URL('https://w.soundcloud.com/player/');
  url.searchParams.set('url', soundcloudResourceUrl(track));
  url.searchParams.set('auto_play', autoPlay ? 'true' : 'false');

  Object.entries(soundcloudWidgetOptions).forEach(([key, value]) => {
    url.searchParams.set(key, value ? 'true' : 'false');
  });

  return url.toString();
};

const loadSoundcloudTrack = (
  widget: SoundcloudWidget | undefined,
  track: ApiProfileMusicItemJSON,
  pendingAutoplayUrlRef: { current: string | undefined },
  loadedUrlRef: { current: string | undefined },
) => {
  if (!widget) {
    return;
  }

  loadedUrlRef.current = track.url;

  widget.load(soundcloudResourceUrl(track), {
    ...soundcloudWidgetOptions,
    auto_play: true,
    callback: () => {
      if (pendingAutoplayUrlRef.current === track.url) {
        widget.play();
      }
    },
  });
};

const soundcloudResourceUrl = (track: ApiProfileMusicItemJSON) =>
  track.provider_id
    ? `https://api.soundcloud.com/tracks/${track.provider_id}`
    : track.url;

const loadSoundcloudWidgetApi = () => {
  if (window.SC?.Widget) {
    return Promise.resolve();
  }

  soundcloudWidgetApiPromise ??= new Promise<void>((resolve, reject) => {
    const existingScript = document.querySelector<HTMLScriptElement>(
      `script[src="${SOUNDCLOUD_WIDGET_API}"]`,
    );

    if (existingScript) {
      existingScript.addEventListener('load', () => {
        resolve();
      });
      existingScript.addEventListener('error', () => {
        reject(new Error('SoundCloud widget API failed to load'));
      });
      return;
    }

    const script = document.createElement('script');
    script.async = true;
    script.src = SOUNDCLOUD_WIDGET_API;
    script.addEventListener('load', () => {
      resolve();
    });
    script.addEventListener('error', () => {
      reject(new Error('SoundCloud widget API failed to load'));
    });
    document.head.appendChild(script);
  });

  return soundcloudWidgetApiPromise;
};
