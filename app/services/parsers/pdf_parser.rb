require 'pdf-reader'

module Parsers
  class PdfParser < BaseParser
    DESCRIPTIONS_TO_IGNORE = ['PAGTO_FATURA']
    LAYOUT_PARSERS = [SicrediAccountStatementPdf, SicrediCreditCardPdf].freeze

    def call
      Tempfile.create(['upload', '.pdf']) do |tmp|
        tmp.binmode
        tmp.write(monthly_statement.file.download)
        tmp.rewind

        reader = PDF::Reader.new(tmp)
        layout_parser = self.class.layout_parser_for(reader)
        next layout_parser.new(monthly_statement, reader).call if layout_parser

        # Legacy Sicredi extrato layout (one transaction per text line).
        lines = reader.pages.flat_map(&:text).flat_map(&:lines)
        parse_lines(lines)
      end
    end

    def self.layout_parser_for(reader)
      first_page_text = reader.pages.first&.text.to_s
      LAYOUT_PARSERS.find { |parser| parser.matches?(first_page_text) }
    end

    private

    def create_summary(status:, content:, error:)
      SummaryLine.create!(monthly_statement: monthly_statement, status: status, content: content.to_json, error: error)
    end

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
          transaction_date: Date.strptime(date_str, '%d/%m/%Y')
        }

        create_transaction(new_entry, [date_str, raw_description, amount_str])
      rescue StandardError => e
        create_summary(status: 'failed', content: line, error: e.message)
      end
    end
  end
end
