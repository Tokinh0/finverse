require 'rails_helper'

RSpec.describe 'Api::V1::Profiles' do
  let(:anonymous) { { 'Authorization' => '' } }

  it 'lists the profiles without signing in, never their passwords' do
    current_profile.update!(name: 'Alex', password: 'letmein42')
    create(:profile, name: 'Blake')

    get '/api/v1/profiles', headers: anonymous

    expect(response).to have_http_status(:ok)
    expect(json.map { _1['name'] }).to eq(%w[Alex Blake])
    expect(json.first).to include('password_protected' => true, 'locale' => 'en')
    expect(response.body).not_to include('digest')
  end

  it 'creates a profile with the default categories' do
    post '/api/v1/profiles', params: { profile: { name: 'Blake', password: 'secret123' } }, headers: anonymous

    expect(response).to have_http_status(:created)
    expect(json).to include('name' => 'Blake', 'password_protected' => true)
    as_profile(Profile.find(json['id'])) { expect(Category.count).to eq(3) }
  end

  it "uses the browser's language for a new profile and its messages" do
    post '/api/v1/profiles', params: { profile: { name: '' } }, headers: anonymous.merge('Accept-Language' => 'pt-BR,pt;q=0.9')

    expect(response).to have_http_status(:unprocessable_content)
    expect(json['errors'].join).to include('Nome')

    post '/api/v1/profiles', params: { profile: { name: 'Blake' } }, headers: anonymous.merge('Accept-Language' => 'pt')
    expect(json['locale']).to eq('pt-BR')
  end
end
