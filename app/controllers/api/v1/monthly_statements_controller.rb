module Api::V1
  class MonthlyStatementsController < ApplicationController
    before_action :set_monthly_statement, only: %i[ show update destroy ]

    def index
      render json: MonthlyStatement.all.map { |s| MonthlyStatementPresenter::Index.new(s) }
    end  

    def show
      render json: @monthly_statement
    end

    def create
      @monthly_statement = MonthlyStatement.new(monthly_statement_params)

      if @monthly_statement.save
        if @monthly_statement.parse_file
          render json: { 
            statement: MonthlyStatementPresenter::Show.new(@monthly_statement),
            summary_lines: @monthly_statement.summary_lines.map { |s| SummaryLinePresenter.new(s) }
          }, status: :created
        else
          render json: @monthly_statement.errors, status: :unprocessable_entity
        end
      else
        render json: @monthly_statement.errors, status: :unprocessable_entity
      end
    end

    def destroy
      @monthly_statement.destroy!
    end

    private

      def set_monthly_statement
        @monthly_statement = MonthlyStatement.find(params[:id])
      end

      def monthly_statement_params
        params.require(:monthly_statement).permit(:file, :status, :uploaded_at)
      end
  end
end