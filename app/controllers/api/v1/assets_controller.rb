module Api::V1
  class AssetsController < ApplicationController
    before_action :set_asset, only: %i[ show update destroy ]
  
    # GET /assets
    def index
      @assets = Asset.all
  
      render json: @assets
    end
  
    # GET /assets/1
    def show
      render json: @asset
    end
  
    # POST /assets
    def create
      @asset = Asset.new(asset_params)
  
      if @asset.save
        render json: AssetPresenter.new(@asset).as_json, status: :created
      else
        render json: @asset.errors, status: :unprocessable_entity
      end
    end
  
    # PATCH/PUT /assets/1
    def update
      if @asset.update(asset_params)
        render json: @asset
      else
        render json: @asset.errors, status: :unprocessable_entity
      end
    end
  
    # DELETE /assets/1
    def destroy
      @asset.destroy!
    end
  
    private
      # Use callbacks to share common setup or constraints between actions.
      def set_asset
        @asset = Asset.find(params[:id])
      end
  
      # Only allow a list of trusted parameters through.
      def asset_params
        params.require(:asset).permit(:asset_type, :ticker, :description, :current_value, :rating, :quantity)
      end
  end
end  