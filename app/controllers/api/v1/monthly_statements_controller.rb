module Api::V1
  class MonthlyStatementsController < ApplicationController
    before_action :set_monthly_statement, only: %i[ show update destroy ]

    # GET /monthly_statements
    def index
      render json: MonthlyStatement.all.map { |s| MonthlyStatementPresenter::Index.new(s) }
    end  

    # GET /monthly_statements/1
    def show
      render json: @monthly_statement
    end

    # POST /monthly_statements
    def create
      @monthly_statement = MonthlyStatement.new(monthly_statement_params)

      if @monthly_statement.save
        if @monthly_statement.parse_file
          render json: MonthlyStatementPresenter::Show.new(@monthly_statement), status: :created
        else
          render json: @monthly_statement.errors, status: :unprocessable_entity
        end
      else
        render json: @monthly_statement.errors, status: :unprocessable_entity
      end
      
    end

    # PATCH/PUT /monthly_statements/1
    def update
      if @monthly_statement.update(monthly_statement_params)
        render json: @monthly_statement
      else
        render json: @monthly_statement.errors, status: :unprocessable_entity
      end
    end

    # DELETE /monthly_statements/1
    def destroy
      @monthly_statement.destroy!
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_monthly_statement
        @monthly_statement = MonthlyStatement.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def monthly_statement_params
        params.require(:monthly_statement).permit(:file, :status, :uploaded_at)
      end
  end
end