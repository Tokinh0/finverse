module Api::V1
  class ReportsController < ApplicationController
    def monthly_by_category
      render json: Reports::MonthlyByCategory.call
    end
  end
end
