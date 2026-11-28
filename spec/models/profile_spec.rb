require 'rails_helper'

RSpec.describe Profile do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_inclusion_of(:locale).in_array(Profile::LOCALES) }

  it 'needs a name unique in its account, ignoring case and extra spaces' do
    create(:profile, name: 'Blake')

    expect(build(:profile, name: ' blake ')).not_to be_valid
    expect(build(:profile, name: 'Blake', account: create(:account))).to be_valid
  end

  it 'limits how many profiles an account has' do
    account = create(:account)
    create_list(:profile, Account::MAX_PROFILES, account: account)

    profile = build(:profile, account: account)
    expect(profile).not_to be_valid
    expect(profile.errors[:base].join).to include(Account::MAX_PROFILES.to_s)
  end

  describe 'password' do
    it 'is optional' do
      profile = create(:profile)

      expect(profile).not_to be_password_protected
      expect(profile.unlocks_with?(nil)).to be(true)
      expect(profile.unlocks_with?('anything')).to be(true)
    end

    it 'unlocks only with the right password, stored as a digest' do
      profile = create(:profile, password: 'letmein42')

      expect(profile).to be_password_protected
      expect(profile.password_digest).not_to include('letmein42')
      expect(profile.unlocks_with?('letmein42')).to be(true)
      expect(profile.unlocks_with?('wrong')).to be(false)
      expect(profile.unlocks_with?(nil)).to be(false)
    end

    it 'must have at least 4 characters' do
      expect(build(:profile, password: 'abc')).not_to be_valid
    end
  end
end
