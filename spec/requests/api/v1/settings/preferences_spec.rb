require 'rails_helper'

RSpec.describe 'Api::V1::Settings::Preferences' do
  it 'reads and changes the language' do
    get '/api/v1/settings/preferences'
    expect(json).to eq('locale' => 'en', 'available_locales' => %w[en pt-BR])

    put '/api/v1/settings/preferences', params: { preferences: { locale: 'pt-BR' } }
    expect(json['locale']).to eq('pt-BR')
    expect(AppSetting.current.locale).to eq('pt-BR')
  end

  it 'rejects unknown languages' do
    put '/api/v1/settings/preferences', params: { preferences: { locale: 'fr' } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'answers in the chosen language' do
    AppSetting.current.update!(locale: 'pt-BR')
    create(:subcategory, :other)

    post '/api/v1/suggestion_runs'

    expect(json['errors']).to eq([ 'Nada para sugerir, ou as sugestões já estão sendo geradas' ])
  end
end
