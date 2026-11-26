require 'rails_helper'

RSpec.describe Matchers::DefaultMatcher do
  describe '.match_score' do
    it 'scores exact, whole word, substring and reverse substring matches' do
      expect(described_class.match_score('IFOOD', 'IFOOD')).to eq(4)
      expect(described_class.match_score('PIX IFOOD RESTAURANTE', 'IFOOD')).to eq(3)
      expect(described_class.match_score('COMPRA_IFOOD_SP', 'IFOOD')).to eq(2)
      expect(described_class.match_score('UBER', 'UBER_TRIP')).to eq(1)
      expect(described_class.match_score('NETFLIX', 'SPOTIFY')).to eq(0)
    end
  end

  describe '.compare' do
    it 'normalizes both sides before scoring' do
      expect(described_class.compare(' mc donalds ', 'MC_DONALDS')).to eq(4)
    end
  end

  describe '.find_best_keyword_match' do
    it 'returns the keyword with the highest score' do
      create(:keyword, name: 'PIX')
      best = create(:keyword, name: 'PIX_IFOOD')

      expect(described_class.find_best_keyword_match('pix ifood')).to eq(best)
    end

    it 'returns nil when nothing matches' do
      create(:keyword, name: 'NETFLIX')

      expect(described_class.find_best_keyword_match('SPOTIFY')).to be_nil
    end
  end
end
