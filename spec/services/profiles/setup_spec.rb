require 'rails_helper'

RSpec.describe Profiles::Setup do
  let(:account) { current_profile.account }

  it 'creates the profile with the default categories, inside that profile only' do
    profile = described_class.call(account: account, name: 'Blake', locale: 'pt-BR')

    expect(profile).to be_persisted
    expect(profile.locale).to eq('pt-BR')
    expect(profile).not_to be_password_protected
    as_profile(profile) do
      expect(Category.pluck(:name)).to contain_exactly('Ganhos', 'Conforto', 'Outros')
      expect(Subcategory.other_subcategory).to be_present
      expect(Keyword.count).to eq(3)
    end
    expect(Category.count).to eq(0)
  end

  it 'can set a password' do
    profile = described_class.call(account: account, name: 'Blake', password: 'secret123')

    expect(profile.unlocks_with?('secret123')).to be(true)
  end

  it 'creates nothing when the profile is invalid' do
    profile = described_class.call(account: account, name: '')

    expect(profile).not_to be_persisted
    expect(profile.errors[:name]).to be_present
    expect(Category.unscoped.count).to eq(0)
  end

  it 'creates nothing when the default data fails' do
    allow(Profiles::DefaultData).to receive(:apply).and_raise(ArgumentError, 'broken file')

    expect { described_class.call(account: account, name: 'Blake') }.to raise_error(ArgumentError)
    expect(Profile.where(name: 'Blake')).not_to exist
  end
end
