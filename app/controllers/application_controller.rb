class ApplicationController < ActionController::API
  # Every response (messages, alerts, validation errors) uses the language set in Settings.
  around_action :use_app_locale

  private

  def use_app_locale(&)
    I18n.with_locale(AppSetting.current.locale, &)
  end
end
