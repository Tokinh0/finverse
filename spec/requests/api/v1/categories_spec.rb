require 'rails_helper'

RSpec.describe 'Api::V1::Categories' do
  it 'lists categories with their subcategories' do
    subcategory = create(:subcategory)

    get '/api/v1/categories'

    expect(json).to contain_exactly(a_hash_including('id' => subcategory.category_id, 'subcategories' => [a_hash_including('id' => subcategory.id)]))
  end

  it 'creates a category' do
    post '/api/v1/categories', params: { category: { name: 'Lazer', color_code: '#000000' } }

    expect(response).to have_http_status(:created)
    expect(Category.last).to have_attributes(name: 'Lazer', parsed_name: 'LAZER')
  end

  it 'returns validation errors' do
    post '/api/v1/categories', params: { category: { name: '' } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['errors']).to include("Name can't be blank")
  end

  it 'updates a category, keeping parsed_name in sync' do
    category = create(:category, name: 'Lazer')

    patch "/api/v1/categories/#{category.id}", params: { category: { name: 'Viagem' } }

    expect(json).to include('name' => 'Viagem')
    expect(category.reload.parsed_name).to eq('VIAGEM')
  end

  it 'destroys a category and its subcategories' do
    subcategory = create(:subcategory)

    delete "/api/v1/categories/#{subcategory.category_id}"

    expect(Subcategory.exists?(subcategory.id)).to be(false)
  end
end
