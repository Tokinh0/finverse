module Api::V1
  class ReportsController < ApplicationController
    def monthly_by_category
      render json: Reports::MonthlyByCategory.call
    end

    def monthly_by_subcategory
      render json: Reports::MonthlyBySubcategory.call
    end

    # GET /reports/financial_health?period=1|3|6|12&as_of=YYYY-MM&year=YYYY
    def financial_health
      render json: Reports::FinancialHealth.call(period: params[:period], as_of: params[:as_of], year: params[:year])
    end
  end
end
