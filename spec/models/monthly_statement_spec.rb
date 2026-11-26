require 'rails_helper'

RSpec.describe MonthlyStatement do
  it { is_expected.to have_many(:transactions).dependent(:destroy) }
  it { is_expected.to have_many(:summary_lines).dependent(:destroy) }

  it 'starts as unprocessed' do
    expect(described_class.new).to be_unprocessed
  end
end
