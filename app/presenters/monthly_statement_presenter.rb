# frozen_string_literal: true

class MonthlyStatementPresenter
  include Rails.application.routes.url_helpers

  # @param transactions_count [Integer, nil] pass it when presenting many statements (one query
  #   for all); otherwise it is counted here.
  def initialize(statement, transactions_count: nil)
    @statement = statement
    @transactions_count = transactions_count
  end

  def as_json(*)
    {
      id: @statement.id,
      filename: @statement.file&.filename&.to_s,
      created_at: @statement.created_at.strftime("%Y-%m-%d"),
      first_transaction_date: @statement.first_transaction_date,
      last_transaction_date: @statement.last_transaction_date,
      statement_kind: @statement.statement_kind,
      status: @statement.status,
      transactions_count: @transactions_count || @statement.transactions.count,
      url: @statement.file.attached? ? url_for(@statement.file) : nil
    }
  end
end
