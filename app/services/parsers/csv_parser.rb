require 'csv'

module Parsers
  class CsvParser < BaseParser
    CSV_CONTENT_START_LINE = 15
    DESCRIPTIONS_TO_IGNORE = ['PAG_FAT_DEB_CC']

    def call
      monthly_statement.file.open do |tempfile|
        csv_data = CSV.read(tempfile.path, headers: true, skip_blanks: true, liberal_parsing: true)
        csv_data.drop(CSV_CONTENT_START_LINE).each { |row| parse_row(row) }
      end
    end

    private

    def parse_row(row)
      fields = row.fields.compact
      parts = fields.join(';').split(';').map(&:strip)

      unless parts[0] =~ /^\d{2}\/\d{2}\/\d{4}$/
        return create_summary(status: 'skipped', error: 'malformed_row', content: parts)
      end

      name = parts[1]
      parsed_name = default_string_parse(name)
      return if DESCRIPTIONS_TO_IGNORE.any? { |w| parsed_name.include?(w) }

      raw_value_part1 = parts[3].gsub(/\D/, '')
      raw_value_part2 = parts[4].gsub(/\D/, '')
      return if raw_value_part1.blank? || raw_value_part2.blank?

      amount = "#{raw_value_part1}.#{raw_value_part2}".to_f
      if name.blank? || amount.zero?
        return create_summary(status: 'skipped', error: 'name_or_amount_missing', content: parts)
      end

      new_entry = {
        name: name,
        amount: amount,
        transaction_date: DateTime.parse(parts[0]),
        transaction_type: 'debit'
      }

      create_transaction(new_entry, parts)
    end
  end
end
