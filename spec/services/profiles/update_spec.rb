require 'rails_helper'

RSpec.describe Profiles::Update do
  it 'changes the name and language' do
    profile = described_class.call(current_profile, { name: 'Alex', locale: 'pt-BR' })

    expect(profile.errors).to be_empty
    expect(current_profile.reload).to have_attributes(name: 'Alex', locale: 'pt-BR')
  end

  it 'sets a password on a profile without one, no current password needed' do
    described_class.call(current_profile, { password: 'secret123' })

    expect(current_profile.reload.unlocks_with?('secret123')).to be(true)
  end

  context 'with a password' do
    let(:profile) { create(:profile, :with_password) }

    it 'needs the current password to change it' do
      result = described_class.call(profile, { password: 'newpass1', current_password: 'nope' })

      expect(result.errors[:current_password]).to be_present
      expect(profile.reload.unlocks_with?('secret123')).to be(true)
    end

    it 'changes it and signs out the other sessions' do
      kept = ProfileSession.start!(profile)
      other = ProfileSession.start!(profile)

      described_class.call(profile, { password: 'newpass1', current_password: 'secret123' }, keep_session: kept)

      expect(profile.reload.unlocks_with?('newpass1')).to be(true)
      expect(ProfileSession.exists?(kept.id)).to be(true)
      expect(ProfileSession.exists?(other.id)).to be(false)
    end

    it 'removes it with the current password' do
      described_class.call(profile, { remove_password: 'true', current_password: 'secret123' })

      expect(profile.reload).not_to be_password_protected
    end

    it 'renames without the password' do
      described_class.call(profile, { name: 'New name' })

      expect(profile.reload.name).to eq('New name')
    end
  end

  it 'reports invalid changes without saving' do
    result = described_class.call(current_profile, { name: '' })

    expect(result.errors[:name]).to be_present
    expect(current_profile.reload.name).to be_present
  end
end
