# frozen_string_literal: true

class Settings::ProfilesController < Settings::BaseController
  before_action :set_account

  def show
    @account.build_fields
  end

  def update
    if UpdateAccountService.new.call(@account, account_params)
      ActivityPub::UpdateDistributionWorker.perform_in(ActivityPub::UpdateDistributionWorker::DEBOUNCE_DELAY, @account.id)
      redirect_to settings_profile_path, notice: I18n.t('generic.changes_saved_msg')
    else
      @account.build_fields
      render :show
    end
  end

  private

  def account_params
    params.expect(
      account: [
        :display_name,
        :note,
        :avatar,
        :header,
        :profile_background,
        :profile_background_color,
        :profile_accent_color,
        :profile_font,
        :profile_custom_css,
        :bot,
        fields_attributes: [[:name, :value]],
        profile_music: [[:provider, :provider_id, :url, :title, :artist, :thumbnail_url]],
      ]
    )
  end

  def set_account
    @account = current_account
  end
end
