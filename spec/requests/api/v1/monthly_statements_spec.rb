require 'rails_helper'

RSpec.describe 'Api::V1::MonthlyStatements' do
  before { create(:subcategory, :other) }

  def upload(content, filename:, content_type:)
    file = Rack::Test::UploadedFile.new(StringIO.new(content), content_type, original_filename: filename)
    post '/api/v1/monthly_statements', params: { monthly_statement: { file: file } }
  end

  it 'imports an uploaded CSV and returns the statement with its summary lines' do
    upload(sicredi_csv('05/01/2025;IFOOD;;"R$ 60,28";;;C'), filename: 'fatura.csv', content_type: 'text/csv')

    expect(response).to have_http_status(:created)
    expect(json['statement']).to include('filename' => 'fatura.csv', 'status' => 'processed', 'first_transaction_date' => '2025-01-05')
    expect(json['summary_lines']).to contain_exactly(a_hash_including('status' => 'processed', 'parsed_transaction' => a_hash_including('amount' => 60.28)))
  end

  it 'starts generating suggestions for what keyword rules left uncategorized' do
    expect {
      upload(sicredi_csv('05/01/2025;IFOOD;;"R$ 60,28";;;C'), filename: 'fatura.csv', content_type: 'text/csv')
    }.to have_enqueued_job(GenerateSuggestionsJob)

    expect(json['suggestion_run']).to include('status' => 'queued', 'monthly_statement_id' => json['statement']['id'])
    expect(json['statement']).to include('statement_kind' => 'credit_card')
  end

  it 'responds 422 for unsupported files' do
    upload('hello', filename: 'notes.txt', content_type: 'text/plain')

    expect(response).to have_http_status(:unprocessable_content)
    expect(json['file'].first).to match(/Unsupported file type/)
  end

  it 'lists, shows and destroys statements' do
    statement = create(:monthly_statement)
    create(:transaction, monthly_statement: statement)

    get '/api/v1/monthly_statements'
    expect(json).to contain_exactly(a_hash_including('id' => statement.id, 'transactions_count' => 1))

    get "/api/v1/monthly_statements/#{statement.id}"
    expect(json).to include('id' => statement.id, 'status' => 'unprocessed', 'transactions_count' => 1)

    expect { delete "/api/v1/monthly_statements/#{statement.id}" }.to change(Transaction, :count).by(-1)
  end
end
