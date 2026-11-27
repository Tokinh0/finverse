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

    # GET /reports/categorization_progress?months=6
    def categorization_progress
      months = params[:months].to_i.clamp(1, 24)
      months = 6 if params[:months].blank?
      render json: Reports::CategorizationProgress.call(months: months)
    end
  end
end
