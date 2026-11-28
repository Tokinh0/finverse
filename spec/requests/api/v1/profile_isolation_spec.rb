require 'rails_helper'

# Each profile only ever sees and changes its own data.
RSpec.describe 'Profile isolation' do
  let(:other) { create(:profile) }
  let!(:mine) { create(:transaction, name: 'MINE') }
  let!(:theirs) { as_profile(other) { create(:transaction, name: 'THEIRS') } }

  it 'lists only the signed-in profile data' do
    get '/api/v1/transactions'
    expect(json['transactions'].map { _1['name'] }).to eq([ 'MINE' ])

    get '/api/v1/transactions', headers: auth_headers(other)
    expect(json['transactions'].map { _1['name'] }).to eq([ 'THEIRS' ])

    get '/api/v1/categories'
    expect(json.map { _1['id'] }).to contain_exactly(mine.subcategory.category_id)
  end

  it "can't change another profile's records" do
    patch "/api/v1/transactions/#{theirs.id}", params: { transaction: { transaction_type: 'credit' } }
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/keywords/#{as_profile(other) { create(:keyword) }.id}"
    expect(response).to have_http_status(:not_found)
    expect(as_profile(other) { Keyword.count }).to eq(1)
  end

  it "can't point a record at another profile's subcategory" do
    their_subcategory = as_profile(other) { create(:subcategory) }

    post '/api/v1/keywords', params: { keyword: { name: 'NETFLIX', subcategory_id: their_subcategory.id } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Keyword.unscoped.where(parsed_name: 'NETFLIX')).not_to exist
  end

  it 'shares the Claude settings across the profiles of the account' do
    put '/api/v1/settings/claude', params: { claude: { model: 'claude-sonnet-5-5' } }

    get '/api/v1/settings/claude', headers: auth_headers(other)
    expect(json['model']).to eq('claude-sonnet-5-5')
  end
end
