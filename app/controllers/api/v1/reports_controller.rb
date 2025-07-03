module Api::V1
  class ReportsController < ApplicationController
    def monthly_by_category
      render json: Reports::MonthlyByCategory.call
    end

    def monthly_by_subcategory
      render json: Reports::MonthlyBySubcategory.call
    end
  end
end
