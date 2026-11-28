module Api::V1::Settings
  # GET/PUT/DELETE /settings/market: the account's brapi.dev token (B3 and Ibovespa quotes).
  # Like the Claude key, only a masked form ever comes back.
  class MarketController < ApplicationController
    def show
      render json: presented
    end

    # Body: { market: { brapi_token } }
    def update
      token = params.fetch(:market, {}).permit(:brapi_token)[:brapi_token].to_s.strip.presence
      return render json: { errors: [ I18n.t("market.token_blank") ] }, status: :unprocessable_content unless token

      setting.update!(brapi_token: token)
      ::Market.cache.clear
      render json: presented
    end

    def destroy
      setting.update!(brapi_token: nil)
      ::Market.cache.clear
      render json: presented
    end

    private

    def setting
      @setting ||= AppSetting.current
    end

    def presented
      {
        brapi_configured: setting.brapi_token.present?,
        masked_brapi_token: setting.masked_brapi_token,
        brapi_from_env: setting.brapi_token.blank? && ENV["BRAPI_TOKEN"].present?
      }
    end
  end
end
