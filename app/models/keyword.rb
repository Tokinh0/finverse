class Keyword < ApplicationRecord
  include Normalizer

  belongs_to :subcategory

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :subcategory_id }

  enum keyword_type: { debit: 'debit', credit: 'credit', unknown: 'unknown', ignored: 'ignored' }

  after_initialize :set_keyword_type, if: -> { new_record? && keyword_type.nil? }

  delegate :category, to: :subcategory

  scope :has_word, ->(word) { where("name ILIKE ?", "%#{word}%") }

  def set_keyword_type
    self.keyword_type = self.class.infer_keyword_type(parsed_name)
  end
  
  # Class-level keyword helpers
  class << self
    def seed_data
      @seed_data ||= JsonUtils.load_initial_data
    end

    def debit_keywords
      @debit_keywords ||= (seed_data['debit_keywords'] || []).map { |k| default_string_parse(k) }
    end

    def credit_keywords
      @credit_keywords ||= (seed_data['credit_keywords'] || []).map { |k| default_string_parse(k) }
    end

    def ignored_keywords
      @ignored_keywords ||= (seed_data['ignored_keywords'] || []).map { |k| default_string_parse(k) }
    end

    def infer_keyword_type(parsed_name)
      credit_score = credit_keywords.map { |word| Matchers::DefaultMatcher.compare(word, parsed_name) }.max || 0
      debit_score = debit_keywords.map { |word| Matchers::DefaultMatcher.compare(word, parsed_name) }.max || 0
      ignored_score = ignored_keywords.map { |word| Matchers::DefaultMatcher.compare(word, parsed_name) }.max || 0
    
      max_score = [debit_score, credit_score, ignored_score].max
    
      case max_score
      when debit_score then :debit
      when credit_score then :credit
      when ignored_score then :ignored
      else :unknown
      end
    end
    
  end
end
