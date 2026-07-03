import type { ChangeEventHandler, FC } from 'react';
import { useCallback, useState } from 'react';

import { FormattedMessage, useIntl } from 'react-intl';

import type { ApiProfileFont } from '@/mastodon/api_types/profile_theme';
import { Button } from '@/mastodon/components/button';
import { Callout } from '@/mastodon/components/callout';
import {
  SelectField,
  TextAreaField,
  TextInputField,
  ToggleField,
} from '@/mastodon/components/form_fields';
import { LoadingIndicator } from '@/mastodon/components/loading_indicator';
import { patchProfile } from '@/mastodon/reducers/slices/profile_edit';
import type { ProfileEditState } from '@/mastodon/reducers/slices/profile_edit';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';

import type { DialogModalProps } from '../../ui/components/dialog_modal';
import { DialogModal } from '../../ui/components/dialog_modal';
import { messages } from '../index';

import classes from './styles.module.scss';

export const ProfileDisplayModal: FC<DialogModalProps> = ({ onClose }) => {
  const { profile, isPending } = useAppSelector((state) => state.profileEdit);

  if (!profile) {
    return <LoadingIndicator />;
  }

  return (
    <ProfileDisplayModalContent
      key={profile.id}
      onClose={onClose}
      profile={profile}
      isPending={isPending}
    />
  );
};

const ProfileDisplayModalContent: FC<
  DialogModalProps & {
    profile: NonNullable<ProfileEditState['profile']>;
    isPending: boolean;
  }
> = ({ onClose, profile, isPending }) => {
  const intl = useIntl();

  const serverName = useAppSelector(
    (state) => state.meta.get('domain') as string,
  );

  const dispatch = useAppDispatch();
  const [backgroundColor, setBackgroundColor] = useState(
    profile.profileBackgroundColor,
  );
  const [accentColor, setAccentColor] = useState(profile.profileAccentColor);
  const [font, setFont] = useState<ApiProfileFont>(profile.profileFont);
  const [customCss, setCustomCss] = useState(profile.profileCustomCss);

  const handleToggleChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const { name, checked } = event.target;
      const targetChecked = name === 'hide_collections' ? !checked : checked;
      void dispatch(patchProfile({ [name]: targetChecked }));
    },
    [dispatch],
  );

  const handleBackgroundColorChange: ChangeEventHandler<HTMLInputElement> =
    useCallback((event) => {
      setBackgroundColor(event.currentTarget.value);
    }, []);

  const handleAccentColorChange: ChangeEventHandler<HTMLInputElement> =
    useCallback((event) => {
      setAccentColor(event.currentTarget.value);
    }, []);

  const handleFontChange: ChangeEventHandler<HTMLSelectElement> = useCallback(
    (event) => {
      setFont(event.currentTarget.value as ApiProfileFont);
    },
    [],
  );

  const handleCustomCssChange: ChangeEventHandler<HTMLTextAreaElement> =
    useCallback((event) => {
      setCustomCss(event.currentTarget.value);
    }, []);

  const handleStyleSave = useCallback(() => {
    void dispatch(
      patchProfile({
        profile_background_color: backgroundColor,
        profile_accent_color: accentColor,
        profile_font: font,
        profile_custom_css: customCss,
      }),
    );
  }, [accentColor, backgroundColor, customCss, dispatch, font]);

  return (
    <DialogModal
      onClose={onClose}
      title={intl.formatMessage(messages.profileTabTitle)}
      buttons={
        <Button onClick={handleStyleSave} disabled={isPending}>
          <FormattedMessage
            id='account_edit.profile_style.save'
            defaultMessage='Save style'
          />
        </Button>
      }
    >
      <div className={classes.profileStyleWrapper}>
        <TextInputField
          type='color'
          value={backgroundColor || '#000000'}
          onChange={handleBackgroundColorChange}
          disabled={isPending}
          label={
            <FormattedMessage
              id='account_edit.profile_style.background_color'
              defaultMessage='Background color'
            />
          }
        />

        <TextInputField
          type='color'
          value={accentColor || '#6364ff'}
          onChange={handleAccentColorChange}
          disabled={isPending}
          label={
            <FormattedMessage
              id='account_edit.profile_style.accent_color'
              defaultMessage='Accent color'
            />
          }
        />

        <SelectField
          value={font}
          onChange={handleFontChange}
          disabled={isPending}
          label={
            <FormattedMessage
              id='account_edit.profile_style.font'
              defaultMessage='Handle font'
            />
          }
          hint={
            <FormattedMessage
              id='account_edit.profile_style.font_hint'
              defaultMessage='This font applies to your name and handle anywhere your posts are shown.'
            />
          }
        >
          <option value='system'>
            {intl.formatMessage({
              id: 'account_edit.profile_style.font.system',
              defaultMessage: 'System default',
            })}
          </option>
          <option value='sans'>
            {intl.formatMessage({
              id: 'account_edit.profile_style.font.sans',
              defaultMessage: 'Sans serif',
            })}
          </option>
          <option value='serif'>
            {intl.formatMessage({
              id: 'account_edit.profile_style.font.serif',
              defaultMessage: 'Serif',
            })}
          </option>
          <option value='mono'>
            {intl.formatMessage({
              id: 'account_edit.profile_style.font.mono',
              defaultMessage: 'Monospace',
            })}
          </option>
          <option value='pixel'>
            {intl.formatMessage({
              id: 'account_edit.profile_style.font.pixel',
              defaultMessage: 'Pixel',
            })}
          </option>
        </SelectField>

        <TextAreaField
          value={customCss}
          onChange={handleCustomCssChange}
          disabled={isPending}
          autoSize
          minRows={8}
          label={
            <FormattedMessage
              id='account_edit.profile_style.custom_css'
              defaultMessage='Custom CSS'
            />
          }
          hint={
            <FormattedMessage
              id='account_edit.profile_style.custom_css_hint'
              defaultMessage='CSS is scoped to your own profile page.'
            />
          }
        />
      </div>

      <div className={classes.toggleInputWrapper}>
        <ToggleField
          checked={profile.showMedia}
          onChange={handleToggleChange}
          disabled={isPending}
          name='show_media'
          label={
            <FormattedMessage
              id='account_edit.profile_tab.show_media.title'
              defaultMessage='Show ‘Media’ tab'
            />
          }
          hint={
            <FormattedMessage
              id='account_edit.profile_tab.show_media.description'
              defaultMessage='‘Media’ is an optional tab that shows your posts containing images or videos.'
            />
          }
        />

        {profile.showMedia && (
          <ToggleField
            checked={profile.showMediaReplies}
            onChange={handleToggleChange}
            disabled={isPending}
            name='show_media_replies'
            label={
              <FormattedMessage
                id='account_edit.profile_tab.show_media_replies.title'
                defaultMessage='Include replies on ‘Media’ tab'
              />
            }
            hint={
              <FormattedMessage
                id='account_edit.profile_tab.show_media_replies.description'
                defaultMessage='When enabled, Media tab shows both your posts and replies to other people’s posts.'
              />
            }
          />
        )}

        <ToggleField
          checked={profile.showFeatured}
          onChange={handleToggleChange}
          disabled={isPending}
          name='show_featured'
          label={
            <FormattedMessage
              id='account_edit.profile_tab.show_featured.title'
              defaultMessage='Show ‘My Top 8’ tab'
            />
          }
          hint={
            <FormattedMessage
              id='account_edit.profile_tab.show_featured.description'
              defaultMessage='‘My Top 8’ is an optional tab where you can showcase your favorite accounts and collections.'
            />
          }
        />

        <ToggleField
          checked={!profile.hideCollections}
          onChange={handleToggleChange}
          disabled={isPending}
          name='hide_collections'
          label={
            <FormattedMessage
              id='account_edit.profile_tab.show_relations.title'
              defaultMessage='Show ‘Followers’ and ‘Following’'
            />
          }
          hint={
            <FormattedMessage
              id='account_edit.profile_tab.show_relations.description'
              defaultMessage='Shows accounts you follow and follows you to other users in your profile. People will still be able to see if you are following them.'
            />
          }
        />
      </div>

      <Callout
        title={
          <FormattedMessage
            id='account_edit.profile_tab.hint.title'
            defaultMessage='Displays still vary'
          />
        }
        icon={false}
      >
        <FormattedMessage
          id='account_edit.profile_tab.hint.description'
          defaultMessage='These settings customize what users see on {server} in the official apps, but they may not apply to users on other servers and 3rd party apps.'
          values={{
            server: serverName,
          }}
        />
      </Callout>
    </DialogModal>
  );
};
