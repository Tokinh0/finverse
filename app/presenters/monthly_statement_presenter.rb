# app/presenters/monthly_statement_presenter.rb
# frozen_string_literal: true

module MonthlyStatementPresenter
  class Index
    include Rails.application.routes.url_helpers

    def initialize(statement)
      @statement = statement
    end

    def as_json(*)
      {
        id: @statement.id,
        filename: @statement.file&.filename&.to_s,
        created_at: @statement.created_at.strftime("%Y-%m-%d"),
        first_transaction_date: @statement.first_transaction_date,
        last_transaction_date: @statement.last_transaction_date,
        statement_type: @statement.statement_type,
        url: @statement.file.attached? ? url_for(@statement.file) : nil
      }
    end
  end

  class Show
    include Rails.application.routes.url_helpers

    def initialize(statement)
      @statement = statement
    end

    def as_json(*)
      {
        id: @statement.id,
        filename: @statement.file&.filename&.to_s,
        created_at: @statement.created_at.strftime("%Y-%m-%d"),
        first_transaction_date: @statement.first_transaction_date,
        last_transaction_date: @statement.last_transaction_date,
        statement_type: @statement.statement_type,
        url: @statement.file.attached? ? url_for(@statement.file) : nil
      }
    end
  end
end
