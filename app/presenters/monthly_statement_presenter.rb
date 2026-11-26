# frozen_string_literal: true

class MonthlyStatementPresenter
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
      status: @statement.status,
      url: @statement.file.attached? ? url_for(@statement.file) : nil
    }
  end
end
