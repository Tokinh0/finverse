module Transactions
  # Merchant identity shared by alerts and reports: the normalized name without digits, so
  # "PAGAMENTO_PIX_123_JOAO" and "PAGAMENTO_PIX_456_JOAO" count as the same merchant.
  module Merchant
    module_function

    def key(transaction)
      (transaction.parsed_name || StringUtils.default_string_parse(transaction.name))
        .gsub(/\d+/, "").squeeze("_").delete_prefix("_").delete_suffix("_")
    end
  end
end
