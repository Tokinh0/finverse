module Api::V1
  class PortfolioDashboardController < ApplicationController
    def index
      render json: Portfolio::Dashboard.call
    end
  end
end
