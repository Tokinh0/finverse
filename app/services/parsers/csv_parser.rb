require 'csv'

module Parsers
  class CsvParser
    CSV_CONTENT_START_LINE = 15
    DESCRIPTIONS_TO_IGNORE = ['PAG_FAT_DEB_CC']

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    def call
      data = []

      @monthly_statement.file.open do |tempfile|
        csv_data = CSV.read(tempfile.path, headers: true, skip_blanks: true, liberal_parsing: true)
        csv_data.drop(CSV_CONTENT_START_LINE).each do |row|
          data << parse_malformed_row(row)
        end
      end

      data.compact
    end

    private

    def parse_malformed_row(row)
      fields = row.fields.compact
      parts = fields.join(';').split(';').map(&:strip)

      return nil unless parts[0] =~ /^\d{2}\/\d{2}\/\d{4}$/ # date check

      date = parts[0]
      parsed_name = parts[1].strip.upcase.gsub(/\s+/, '_')
      return nil if DESCRIPTIONS_TO_IGNORE.any? { |w| parsed_name.include?(w) }

      value_part1 = parts[3].gsub(/[^\d]/, '')
      value_part2 = parts[4].gsub(/[^\d]/, '')
      amount = "#{value_part1}.#{value_part2}".to_f
      amount *= -1 if amount.negative?

      new_entry = {
        name: parts[1],
        parsed_name: parsed_name,
        amount: amount,
        transaction_date: DateTime.parse(date),
        transaction_type: 'debit'
      }

      Transaction.find_or_create_by(
        Categorization.call(new_entry).merge({ monthly_statement_id: @monthly_statement.id })
      )
    end
  end
end
