import { createSlice } from '@reduxjs/toolkit';

import { apiGetAccountProfileTheme } from '@/mastodon/api/accounts';
import type { ApiProfileThemeJSON } from '@/mastodon/api_types/profile_theme';
import {
  createAppSelector,
  createDataLoadingThunk,
} from '@/mastodon/store/typed_functions';

interface ProfileThemeArgs extends Record<string, unknown> {
  accountId: string;
}

type QueryStatus = 'idle' | 'loading' | 'error';

interface ProfileThemeState {
  byAccountId: Record<string, ApiProfileThemeJSON>;
  statusByAccountId: Record<string, QueryStatus>;
}

const initialState: ProfileThemeState = {
  byAccountId: {},
  statusByAccountId: {},
};

const profileThemeSlice = createSlice({
  name: 'profileTheme',
  initialState,
  reducers: {},
  extraReducers(builder) {
    builder.addCase(fetchProfileTheme.pending, (state, action) => {
      state.statusByAccountId[action.meta.arg.accountId] = 'loading';
    });
    builder.addCase(fetchProfileTheme.rejected, (state, action) => {
      state.statusByAccountId[action.meta.arg.accountId] = 'error';
    });
    builder.addCase(fetchProfileTheme.fulfilled, (state, action) => {
      state.byAccountId[action.meta.arg.accountId] = action.payload;
      state.statusByAccountId[action.meta.arg.accountId] = 'idle';
    });
  },
});

export const profileTheme = profileThemeSlice.reducer;

export const fetchProfileTheme = createDataLoadingThunk<
  ApiProfileThemeJSON,
  ProfileThemeArgs
>(
  `${profileThemeSlice.name}/fetchProfileTheme`,
  ({ accountId }: ProfileThemeArgs) => apiGetAccountProfileTheme(accountId),
  {
    useLoadingBar: false,
    condition({ accountId }, { getState }) {
      const state = getState().profileTheme;
      return state.statusByAccountId[accountId] !== 'loading';
    },
  },
);

export const selectProfileTheme = createAppSelector(
  [
    (state) => state.profileTheme.byAccountId,
    (_, accountId: string) => accountId,
  ],
  (byAccountId, accountId) => byAccountId[accountId],
);
