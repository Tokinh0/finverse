require 'rails_helper'

RSpec.describe Account do
  it { is_expected.to validate_presence_of(:name) }

  describe '.default' do
    it 'returns the first account, creating it when there is none' do
      expect(described_class.default).to eq(current_profile.account)

      Profile.delete_all
      described_class.delete_all
      expect { described_class.default }.to change(described_class, :count).by(1)
      expect(described_class.default.name).to eq(Account::DEFAULT_NAME)
    end
  end

  it 'compares emails case-insensitively' do
    create(:account, email: 'someone@example.com')

    expect(build(:account, email: 'SOMEONE@example.com')).not_to be_valid
    expect(build(:account, email: nil)).to be_valid
  end
end
