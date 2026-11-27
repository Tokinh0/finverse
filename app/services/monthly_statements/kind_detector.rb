module MonthlyStatements
  # Tells whether a stored statement file is a checking account statement or a credit card bill,
  # using the same layout detection as the parsers. Used to backfill old statements.
  module KindDetector
    module_function

    # @return ["checking_account", "credit_card", nil]
    def call(statement)
      case statement.file.content_type
      when "text/csv" then Parsers::CsvParser::STATEMENT_KIND
      when "application/pdf"
        statement.file.open do |file|
          layout = Parsers::PdfParser.layout_parser_for(PDF::Reader.new(file.path))
          layout ? layout::STATEMENT_KIND : "checking_account" # legacy layout is an account statement
        end
      end
    end
  end
end
