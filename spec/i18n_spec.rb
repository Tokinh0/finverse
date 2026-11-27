require 'rails_helper'

RSpec.describe 'Translations' do
  def keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      path = [ prefix, key ].compact.join('.')
      # Pluralization hashes (one/other) count as a single key.
      value.is_a?(Hash) && !(value.keys - %i[zero one few many other]).empty? ? keys(value, path) : [ path ]
    end
  end

  let(:english) { YAML.load_file(Rails.root.join('config/locales/en.yml'))['en'].deep_symbolize_keys }
  let(:portuguese) { YAML.load_file(Rails.root.join('config/locales/pt-BR.yml'))['pt-BR'].deep_symbolize_keys }

  it 'has a Portuguese version of every English message' do
    expect(keys(english) - keys(portuguese)).to eq([])
  end

  it 'uses the same placeholders in both languages' do
    placeholders = ->(text) { text.to_s.scan(/%\{(\w+)\}/).flatten.sort }

    keys(english).each do |key|
      en = I18n.t(key, locale: :en, default: nil)
      pt = I18n.t(key, locale: :'pt-BR', default: nil)
      next unless en.is_a?(String)

      expect(placeholders.call(pt)).to eq(placeholders.call(en)), "placeholders differ for #{key}"
    end
  end
end
