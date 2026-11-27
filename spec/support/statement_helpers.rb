module StatementHelpers
  def statement_with_file(content:, filename:, content_type:)
    statement = MonthlyStatement.new
    statement.file.attach(io: StringIO.new(content), filename: filename, content_type: content_type)
    statement.save!
    statement
  end

  # Mimics the Sicredi credit card CSV export: a header line, 15 preamble lines
  # that the parser skips, then `date;description;;"R$ value";;;card` rows.
  def sicredi_csv(*rows)
    preamble = Array.new(15) { |i| "Resumo linha #{i};\"R$ 1,00\";;;;" }
    ([ "Header;Cartao;;;;" ] + preamble + rows).join("\n")
  end
end

RSpec.configure { |config| config.include StatementHelpers }
