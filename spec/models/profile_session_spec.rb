require 'rails_helper'

RSpec.describe ProfileSession do
  it 'keeps only a digest of the token' do
    session = described_class.start!(current_profile)

    expect(session.token).to be_present
    expect(session.token_digest).to eq(described_class.digest(session.token))
    expect(described_class.find_active(session.token)).to eq(session)
  end

  it 'finds nothing for a blank or unknown token' do
    expect(described_class.find_active(nil)).to be_nil
    expect(described_class.find_active('nope')).to be_nil
  end

  it 'ends sessions left unused for too long' do
    session = described_class.start!(current_profile)
    session.update_column(:last_used_at, (ProfileSession::IDLE_TIMEOUT + 1.minute).ago)

    expect(described_class.find_active(session.token)).to be_nil
    expect(described_class.exists?(session.id)).to be(false)
  end

  it 'records when a session is used, at most once per TOUCH_EVERY' do
    session = described_class.start!(current_profile)
    session.update_column(:last_used_at, 2.hours.ago)

    described_class.find_active(session.token)
    expect(session.reload.last_used_at).to be_within(1.second).of(Time.current)
  end
end
