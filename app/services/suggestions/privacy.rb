module Suggestions
  # Masks long digit runs (CPF/CNPJ, PIX keys, account and document numbers) in text that is
  # sent to Claude. "PAGAMENTO PIX - 123.456.789-09 Maria" becomes "PAGAMENTO PIX - # Maria".
  module Privacy
    LONG_NUMBER = %r{\d[\d.\-/]*\d}
    MIN_DIGITS = 6

    module_function

    def scrub(text)
      text.to_s.gsub(LONG_NUMBER) { |match| match.count("0-9") >= MIN_DIGITS ? "#" : match }.squeeze(" ").strip
    end
  end
end
