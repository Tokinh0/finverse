require 'rails_helper'

RSpec.describe 'Api::V1::CurrentProfile' do
  it 'shows the signed-in profile' do
    get '/api/v1/profile'

    expect(json).to include('id' => current_profile.id, 'name' => current_profile.name)
  end

  it 'renames it and changes its language' do
    patch '/api/v1/profile', params: { profile: { name: 'Alex', locale: 'pt-BR' } }

    expect(response).to have_http_status(:ok)
    expect(json).to include('name' => 'Alex', 'locale' => 'pt-BR')
  end

  it 'sets, changes and removes the password, keeping this session' do
    patch '/api/v1/profile', params: { profile: { password: 'secret123' } }
    expect(json['password_protected']).to be(true)

    patch '/api/v1/profile', params: { profile: { password: 'newpass1', current_password: 'wrong' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(json['errors']).to eq([ 'Current password is wrong' ])

    patch '/api/v1/profile', params: { profile: { remove_password: true, current_password: 'secret123' } }
    expect(response).to have_http_status(:ok)
    expect(json['password_protected']).to be(false)
  end
end
