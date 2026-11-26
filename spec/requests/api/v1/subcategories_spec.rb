require 'rails_helper'

RSpec.describe 'Api::V1::Subcategories' do
  let(:category) { create(:category) }

  it 'lists subcategories with their category' do
    subcategory = create(:subcategory, category: category)

    get '/api/v1/subcategories'

    expect(json).to contain_exactly(a_hash_including('id' => subcategory.id, 'category' => a_hash_including('id' => category.id)))
  end

  it 'creates a subcategory' do
    post '/api/v1/subcategories', params: { subcategory: { name: 'Food', category_id: category.id, subcategory_type: 'expense' } }

    expect(response).to have_http_status(:created)
    expect(json).to include('name' => 'Food', 'subcategory_type' => 'expense')
  end

  it 'returns validation errors' do
    post '/api/v1/subcategories', params: { subcategory: { name: '', category_id: category.id } }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'updates and destroys a subcategory' do
    subcategory = create(:subcategory, category: category)

    patch "/api/v1/subcategories/#{subcategory.id}", params: { subcategory: { name: 'Renamed' } }
    expect(json).to include('name' => 'Renamed')

    expect { delete "/api/v1/subcategories/#{subcategory.id}" }.to change(Subcategory, :count).by(-1)
  end
end
