require 'rails_helper'

RSpec.describe ProfileOwned do
  let(:other) { create(:profile) }

  it 'is included by every model whose table has a profile_id' do
    Rails.application.eager_load!
    connection = ActiveRecord::Base.connection
    tables = connection.tables.select { connection.column_exists?(_1, :profile_id) } - %w[profile_sessions]
    owned = ApplicationRecord.descendants.select { _1.include?(described_class) }

    expect(owned.map(&:table_name)).to match_array(tables)
    expect(owned.map(&:name)).to match_array(%w[
      AlertDismissal Asset CategorizationEvent Category CategorySuggestion Keyword MonthlyStatement RuleSuggestion
      Subcategory SuggestionRun SummaryLine Transaction
    ])
  end

  it 'gives new records the current profile' do
    expect(create(:transaction).profile).to eq(current_profile)
    expect(create(:keyword).subcategory.category.profile).to eq(current_profile)
  end

  it "only shows the current profile's data" do
    mine = create(:transaction)
    theirs = as_profile(other) { create(:transaction) }

    expect(Transaction.all).to contain_exactly(mine)
    expect(Transaction.find_by(id: theirs.id)).to be_nil
    expect(as_profile(other) { Transaction.all.to_a }).to contain_exactly(theirs)
    expect(Transaction.unscoped.count).to eq(2)
  end

  it 'raises instead of mixing data when no profile is selected' do
    Current.profile = nil

    expect { Category.count }.to raise_error(ProfileOwned::MissingProfile)
  end

  it "rejects links to another profile's records" do
    theirs = as_profile(other) { create(:subcategory) }
    their_keyword = as_profile(other) { create(:keyword) }
    transaction = create(:transaction)

    transaction.subcategory_id = theirs.id
    expect(transaction).not_to be_valid

    transaction.reload.subcategory = theirs
    expect(transaction).not_to be_valid
    expect(transaction.errors[:subcategory]).to be_present

    transaction.reload.keyword_id = their_keyword.id
    expect(transaction).not_to be_valid
    expect(transaction.errors[:keyword]).to be_present
  end

  it 'lets each profile use the same category names' do
    create(:category, name: 'Lazer')

    expect(as_profile(other) { build(:category, name: 'Lazer').valid? }).to be(true)
    expect(build(:category, name: 'Lazer')).not_to be_valid
  end
end
