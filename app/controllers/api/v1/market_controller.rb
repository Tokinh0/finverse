module Api::V1
  # GET /market: the market indicators (currencies, crypto, Ibovespa, Brazilian rates).
  class MarketController < ApplicationController
    def show
      render json: ::Market::Overview.call
    end
  end
end
