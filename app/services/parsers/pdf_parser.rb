require 'pdf-reader'

module Parsers
  class PdfParser < BaseParser
    DESCRIPTIONS_TO_IGNORE = ['PAGTO_FATURA']

    def call
      Tempfile.create(['upload', '.pdf']) do |tmp|
        tmp.binmode
        tmp.write(monthly_statement.file.download)
        tmp.rewind

        reader = PDF::Reader.new(tmp)
        lines = reader.pages.flat_map(&:text).flat_map(&:lines)
        parse_lines(lines)
      end
    end

    private

    def parse_lines(lines)
      lines.map(&:strip).reject(&:empty?).each do |line|
        next unless line =~ /^\d{2}\/\d{2}\/\d{4}/

        match = line.match(
          /^(\d{2}\/\d{2}\/\d{4})\s+(.+?)\s+(?:\S+\s+)?(-?\d{1,3}(?:\.\d{3})*,\d{2})\s+(-?\d{1,3}(?:\.\d{3})*,\d{2})?$/
        )
        next unless match

        date_str = match[1]
        raw_description = match[2].strip
        parsed_name = raw_description.upcase.gsub(/\s+/, '_')
        next if DESCRIPTIONS_TO_IGNORE.any? { |w| parsed_name.include?(w) }

        amount_str = match[3]
        next unless amount_str

        amount = amount_str.gsub('.', '').gsub(',', '.').to_f

        new_entry = {
          name: raw_description,
          parsed_name: parsed_name,
          amount: amount,
          transaction_date: Date.strptime(date_str, '%d/%m/%Y'),
          transaction_type: 'debit'
        }

        create_transaction(new_entry, [date_str, raw_description, amount_str])
      end
    end
  end
end
