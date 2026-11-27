require 'rails_helper'

RSpec.describe 'Api::V1::KeywordHealth' do
  it 'reports stats, flags and pending fixes per rule' do
    create(:subcategory, :other)
    keyword = create(:keyword, name: 'NADA')
    fix = create(:rule_suggestion, action: 'delete', keyword: keyword, name: nil, subcategory: nil)

    get '/api/v1/keywords/health'

    expect(json.sole).to include('keyword_id' => keyword.id, 'matches' => 0, 'overrides' => 0, 'flags' => [ 'unused' ],
                                 'pending_suggestion_ids' => [ fix.id ])
  end
end
