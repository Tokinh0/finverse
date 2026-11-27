require 'rails_helper'

RSpec.describe Suggestions::Privacy do
  it 'masks CPFs, CNPJs and long numbers but keeps short ones' do
    expect(described_class.scrub('PAGAMENTO PIX - 123.456.789-09 Maria')).to eq('PAGAMENTO PIX - # Maria')
    expect(described_class.scrub('TED 12.345.678/0001-90 EMPRESA')).to eq('TED # EMPRESA')
    expect(described_class.scrub('PIX 12345678909 JOAO')).to eq('PIX # JOAO')
    expect(described_class.scrub('UBER *TRIP 3 PARCELA 2/10')).to eq('UBER *TRIP 3 PARCELA 2/10')
  end
end
