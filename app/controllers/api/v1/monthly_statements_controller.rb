module Api::V1
  class MonthlyStatementsController < ApplicationController
    before_action :set_monthly_statement, only: %i[show destroy]

    def index
      counts = Transaction.group(:monthly_statement_id).count
      render json: MonthlyStatement.all.map { |s| MonthlyStatementPresenter.new(s, transactions_count: counts.fetch(s.id, 0)) }
    end

    def show
      render json: MonthlyStatementPresenter.new(@monthly_statement)
    end

    def create
      @monthly_statement = MonthlyStatement.new(monthly_statement_params)

      if @monthly_statement.save && MonthlyStatements::Import.call(@monthly_statement)
        run = Suggestions::Enqueue.call(@monthly_statement)
        render json: {
          statement: MonthlyStatementPresenter.new(@monthly_statement),
          suggestion_run: run && SuggestionRunPresenter.new(run),
          summary_lines: @monthly_statement.summary_lines.map { |s| SummaryLinePresenter.new(s) }
        }, status: :created
      else
        render json: @monthly_statement.errors, status: :unprocessable_content
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
        params.require(:monthly_statement).permit(:file)
      end
  end
end
