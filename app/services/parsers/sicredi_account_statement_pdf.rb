module Parsers
  # Sicredi "Extrato de conta corrente" PDF, layout used from mid-2026 on:
  #
  #   Data        Descrição                                            Valor
  #   12/08/2026  PAGAMENTO PIX - 12345678909 Maria Exemplo ...      - R$ 19,00
  #               Saldo do dia 12/08/2026                           R$ 1.234,56
  #
  # Long descriptions wrap above/below the date line, so rows are rebuilt from
  # positioned text runs instead of plain text lines.
  class SicrediAccountStatementPdf < BaseParser
    DATE = %r{\A\d{2}/\d{2}/\d{4}\z}
    AMOUNT = /\A([+-])\s*R\$\s*([\d.]+,\d{2})\z/
    DESCRIPTION_X = (100...490)
    # Card bill payments are already accounted for in the credit card statement.
    DESCRIPTIONS_TO_IGNORE = %w[PAGTO_FATURA PAGAMENTO_DE_FATURA_CARTAO].freeze

    def self.matches?(first_page_text)
      first_page_text.include?("Extrato de conta corrente") &&
        first_page_text.include?("Período das movimentações")
    end

    def initialize(monthly_statement, reader)
      super(monthly_statement)
      @reader = reader
    end

    def call
      rows.each do |row|
        next if row[:ignored]

        if row[:error]
          create_failed_summary(row[:raw], row[:error])
          next
        end

        create_transaction(
          {
            name: row[:name],
            amount: row[:amount],
            transaction_date: row[:date],
            transaction_type: row[:amount].negative? ? "debit" : "credit"
          },
          row[:raw]
        )
      end
    end

    # Every dated row in the statement, including ignored ones (useful to reconcile balances).
    def rows
      @rows ||= PdfTable.rows(@reader, anchor: DATE, anchor_max_x: 100, tolerance: 12, skip: /\ASaldo/)
                        .map { |row| build_row(row) }
    end

    private

    def build_row(row)
      description = row.text_in(DESCRIPTION_X.begin, DESCRIPTION_X.end)
      amount_run = row.same_line_runs.reverse.find { |r| r.text.strip.match?(AMOUNT) }
      raw = [ row.anchor, description, amount_run&.text&.strip ]

      return { raw: raw, error: "amount_not_found" } unless amount_run
      return { raw: raw, error: "description_not_found" } if description.blank?

      sign, value = amount_run.text.strip.match(AMOUNT).captures
      amount = PdfTable.brl_to_f(value) * (sign == "-" ? -1 : 1)
      # Match the legacy layout naming ("PAGAMENTO PIX 0574... NAME"), which keywords rely on.
      name = description.gsub(/\s+-\s+|\s+-\z/, " ").squeeze(" ").strip
      parsed = default_string_parse(name)

      {
        raw: raw,
        name: name,
        amount: amount,
        date: Date.strptime(row.anchor, "%d/%m/%Y"),
        ignored: DESCRIPTIONS_TO_IGNORE.any? { |w| parsed.include?(w) }
      }
    end
  end
end
