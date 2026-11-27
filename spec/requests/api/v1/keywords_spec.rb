require 'rails_helper'

RSpec.describe 'Api::V1::Keywords' do
  let(:subcategory) { create(:subcategory) }

  it 'lists and shows keywords' do
    keyword = create(:keyword, subcategory: subcategory)

    get '/api/v1/keywords'
    expect(json).to contain_exactly(a_hash_including('id' => keyword.id, 'subcategory' => a_hash_including('id' => subcategory.id)))

    get "/api/v1/keywords/#{keyword.id}"
    expect(json).to include('name' => keyword.name)
  end

  it 'creates a keyword, inferring its type' do
    post '/api/v1/keywords', params: { keyword: { name: 'recebimento pix', subcategory_id: subcategory.id } }

    expect(response).to have_http_status(:created)
    expect(json).to include('parsed_name' => 'RECEBIMENTO_PIX', 'keyword_type' => 'credit')
  end

  it 'rejects duplicated keywords in the same subcategory' do
    create(:keyword, name: 'IFOOD', subcategory: subcategory)

    post '/api/v1/keywords', params: { keyword: { name: 'ifood', subcategory_id: subcategory.id } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'updates and destroys a keyword' do
    keyword = create(:keyword, subcategory: subcategory)

    patch "/api/v1/keywords/#{keyword.id}", params: { keyword: { name: 'uber trip' } }
    expect(json).to include('parsed_name' => 'UBER_TRIP')

    delete "/api/v1/keywords/#{keyword.id}"
    expect(response).to have_http_status(:no_content)
  end
end
