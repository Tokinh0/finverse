require 'rails_helper'

RSpec.describe 'db/seeds.rb' do
  def seed
    Current.reset
    original = $stdout
    $stdout = StringIO.new
    load Rails.root.join('db/seeds.rb')
  ensure
    $stdout = original
  end

  around do |example|
    original = ENV['SEED_PROFILES']
    ENV['SEED_PROFILES'] = 'Blake'
    example.run
  ensure
    ENV['SEED_PROFILES'] = original
  end

  before do
    Profile.delete_all
    Account.delete_all
  end

  it 'prepares a fresh install: the account, a Default profile and Blake, with the default categories' do
    seed

    expect(Account.count).to eq(1)
    expect(Profile.order(:id).pluck(:name)).to eq(%w[Default Blake])
    Profile.find_each do |profile|
      expect(profile).not_to be_password_protected
      as_profile(profile) do
        expect(Category.count).to eq(3)
        expect(Subcategory.other_subcategory).to be_present
      end
    end
  end

  it "can run again, and doesn't touch existing profiles" do
    alex = create(:profile, name: 'Alex', account: Account.default)
    as_profile(alex) { create(:category, name: 'Mine') }

    seed
    seed

    expect(Profile.order(:id).pluck(:name)).to eq(%w[Alex Blake])
    as_profile(alex) do
      expect(Category.pluck(:name)).to contain_exactly('Mine', 'Outros')
    end
  end
end
