require 'rails_helper'

RSpec.describe Transaction do
  # Both columns are NOT NULL, so the model requires them too.
  it { is_expected.to belong_to(:subcategory).required }
  it { is_expected.to belong_to(:monthly_statement).required }
  it { is_expected.to have_one(:summary_line).dependent(:destroy) }

  it 'stores the absolute amount rounded to cents' do
    transaction = create(:transaction, amount: -19.999)

    expect(transaction.reload.amount).to eq(20.0)
  end

  it 'normalizes the name into parsed_name' do
    expect(build(:transaction, name: 'Pagamento Pix').parsed_name).to eq('PAGAMENTO_PIX')
  end
end
