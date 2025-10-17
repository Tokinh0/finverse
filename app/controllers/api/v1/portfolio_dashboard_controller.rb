module Api::V1
  class PortfolioDashboardController < ApplicationController
    def index
      assets = Asset.all
      total_value = assets.sum(&:current_value)

      
      portfolio_data = assets.group_by(&:asset_type).map do |category, group|
        value = group.sum(&:current_value)
        {
          name:      category,
          value:     value.to_f,
          percentage:"#{((value / total_value) * 100).round(2)}%",
          color:     group.first.color_code
        }
      end

      render json: { 
        assets: assets.map { |a| AssetPresenter.new(a).as_json },
        portfolioData: portfolio_data
      }
    end

  end
end