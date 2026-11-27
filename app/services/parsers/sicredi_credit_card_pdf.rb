module Parsers
  # Sicredi credit card bill ("fatura") PDF:
  #
  #   Data e hora   Cidade    Compra  Descrição            Parcela  Valor em Dolar  Cotação  Valor em reais
  #   23/jun 18:52  Cidade  Online  Lanchonete Exemplo Ltda                                     R$ 60,28
  #   11/jun 21:14                    Pagamento 000000000                                   -R$ 1.500,00
  #
  # Dates carry no year, so it is inferred from the bill's due date.
  # Negative lines are either bill payments (ignored, they come from the checking
  # account) or refunds/reversals (stored as credits).
  class SicrediCreditCardPdf < BaseParser
    STATEMENT_KIND = "credit_card"
    DATE = %r{\A\d{2}/[a-zç]{3}\s+\d{2}:\d{2}\z}i
    AMOUNT = /\A(-?)R\$\s*([\d.]+,\d{2})\z/
    DESCRIPTION_X = (230...345)
    INSTALLMENT_X = (345...385)
    AMOUNT_MIN_X = 495
    MONTHS = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze
    PAYMENT = /\APagamento\b/i

    def self.matches?(first_page_text)
      first_page_text.match?(/Mastercard .*final/) && first_page_text.include?("Resumo da fatura")
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
            transaction_type: row[:amount].negative? ? "credit" : "debit"
          },
          row[:raw]
        )
      end
    end

    def due_date
      @due_date ||= begin
        text = @reader.pages.first(2).map(&:text).join("\n")
        Date.strptime(text[%r{Vencimento (\d{2}/\d{2}/\d{4})}, 1], "%d/%m/%Y")
      end
    end

    # Every dated row in the bill, including ignored payments (useful to reconcile totals).
    def rows
      @rows ||= PdfTable.rows(@reader, anchor: DATE, anchor_max_x: 100, tolerance: 11)
                        .map { |row| build_row(row) }
    end

    private

    def build_row(row)
      description = row.text_in(DESCRIPTION_X.begin, DESCRIPTION_X.end)
      installment = row.text_in(INSTALLMENT_X.begin, INSTALLMENT_X.end).presence
      amount_run = row.same_line_runs.select { |r| r.x >= AMOUNT_MIN_X }
                      .reverse.find { |r| r.text.strip.match?(AMOUNT) }
      raw = [ row.anchor, description, installment, amount_run&.text&.strip ].compact

      return { raw: raw, error: "amount_not_found" } unless amount_run
      return { raw: raw, error: "description_not_found" } if description.blank?

      sign, value = amount_run.text.strip.match(AMOUNT).captures
      amount = PdfTable.brl_to_f(value) * (sign == "-" ? -1 : 1)

      {
        raw: raw,
        name: description,
        amount: amount,
        date: infer_date(row.anchor),
        ignored: amount.negative? && description.match?(PAYMENT)
      }
    end

    def infer_date(anchor)
      day, month_name = anchor.split.first.split("/")
      month = MONTHS.index(month_name.downcase) + 1
      year = month > due_date.month ? due_date.year - 1 : due_date.year
      Date.new(year, month, day.to_i)
    end
  end
end
