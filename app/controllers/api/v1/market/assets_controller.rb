module Api::V1::Market
  # GET  /market/assets: today's price of each of the profile's assets, next to the saved value.
  # POST /market/assets/apply: saves those prices on the assets. Body: { asset_ids: [..] } (optional;
  # without it every priced asset is updated). Responds with the new valuation.
  class AssetsController < ApplicationController
    def index
      render json: ::Market::AssetValuation.new
    end

    def apply
      updated = ::Market::AssetValuation.new.apply!(ids: params[:asset_ids].presence)
      render json: ::Market::AssetValuation.new.as_json.merge(updated_count: updated.size)
    end
  end
end
