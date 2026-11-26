require 'rails_helper'

RSpec.describe Transaction do
  it { is_expected.to belong_to(:subcategory).optional }
  it { is_expected.to belong_to(:monthly_statement).optional }
  it { is_expected.to have_one(:summary_line).dependent(:destroy) }

  it 'stores the absolute amount rounded to cents' do
    transaction = create(:transaction, amount: -19.999)

    expect(transaction.reload.amount).to eq(20.0)
  end

  it 'normalizes the name into parsed_name' do
    expect(build(:transaction, name: 'Pagamento Pix').parsed_name).to eq('PAGAMENTO_PIX')
  end
end
