require 'rails_helper'

RSpec.describe 'Api::V1::Sessions' do
  let(:anonymous) { { 'Authorization' => '' } }

  it 'signs in a profile without a password' do
    post '/api/v1/session', params: { profile_id: current_profile.id }, headers: anonymous

    expect(response).to have_http_status(:created)
    expect(json['profile']).to include('id' => current_profile.id)

    get '/api/v1/session', headers: { 'Authorization' => "Bearer #{json['token']}" }
    expect(json['profile']['id']).to eq(current_profile.id)
  end

  it 'needs the right password when the profile has one' do
    profile = create(:profile, :with_password)

    post '/api/v1/session', params: { profile_id: profile.id, password: 'wrong' }, headers: anonymous
    expect(response).to have_http_status(:unauthorized)
    expect(json['errors']).to eq([ 'Wrong password' ])

    post '/api/v1/session', params: { profile_id: profile.id }, headers: anonymous
    expect(response).to have_http_status(:unauthorized)

    post '/api/v1/session', params: { profile_id: profile.id, password: 'secret123' }, headers: anonymous
    expect(response).to have_http_status(:created)
  end

  it 'answers 404 for an unknown profile' do
    post '/api/v1/session', params: { profile_id: 0 }, headers: anonymous

    expect(response).to have_http_status(:not_found)
  end

  it 'signs out' do
    headers = auth_headers

    delete '/api/v1/session', headers: headers
    expect(response).to have_http_status(:no_content)

    get '/api/v1/session', headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects data endpoints without a session, in the browser language' do
    get '/api/v1/categories', headers: anonymous.merge('Accept-Language' => 'pt-BR')

    expect(response).to have_http_status(:unauthorized)
    expect(json).to eq('error' => 'unauthenticated', 'errors' => [ 'Escolha um perfil para continuar' ])
  end

  it "answers in the signed-in profile's language" do
    current_profile.update!(locale: 'pt-BR')

    post '/api/v1/categories', params: { category: { name: '' } }, headers: { 'Accept-Language' => 'en' }

    expect(json['errors'].join).to include('Nome')
  end
end
