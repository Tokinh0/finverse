module Api::V1
  class AssetsController < ApplicationController
    before_action :set_asset, only: %i[show update destroy]

    def index
      render json: Asset.order(:id).map { |asset| AssetPresenter.new(asset).as_json }
    end

    def show
      render json: AssetPresenter.new(@asset).as_json
    end

    def create
      asset = Asset.new(asset_params)

      if asset.save
        render json: AssetPresenter.new(asset).as_json, status: :created
      else
        render json: asset.errors, status: :unprocessable_content
      end
    end

    def update
      if @asset.update(asset_params)
        render json: AssetPresenter.new(@asset).as_json
      else
        render json: @asset.errors, status: :unprocessable_content
      end
    end

    def destroy
      @asset.destroy!
    end

    private

      def set_asset
        @asset = Asset.find(params[:id])
      end

      def asset_params
        params.require(:asset).permit(:asset_type, :ticker, :description, :current_value, :rating, :quantity)
      end
  end
end
