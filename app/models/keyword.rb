class Keyword < ApplicationRecord
  include Searchable

  DEBIT_KEYWORDS = [
    'COMPRA',
    'PAGAMENTO',
    'BOLETO',
    'DEBITO',
    'CAPITAL-SUBSCRITO',
    'IOF',
    'MERCADO',
    'CESTA-DE',
    'APLICACAO',
    'PASSAGEM-PEDAGIO',
    'MENSALID',
    'PASSAGEM-ESTACIONAMENTO',
  ]
  CREDIT_KEYWORDS = ['LIBERACAO-CAMBIO', 'TRANSFERENCIA-DA-POUPANCA', 'RECEBIMENTO', 'DISTRIBUICAO']
  
  belongs_to :subcategory
  
  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :subcategory_id }
  
  enum keyword_type: { debit: 'debit', credit: 'credit', unknown: 'unknown' }
  
  after_initialize :set_keyword_type

  delegate :category, to: :subcategory

  scope :has_word, -> (word) { where("name ILIKE ?", "%#{word}%") }

  def set_keyword_type
    if DEBIT_KEYWORDS.include?(parsed_name)
      self.keyword_type = :debit
    elsif CREDIT_KEYWORDS.include?(parsed_name)
      self.keyword_type = :credit
    else
      self.keyword_type = :unknown
    end
  end
end
