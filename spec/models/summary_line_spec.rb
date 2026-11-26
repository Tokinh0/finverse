require 'rails_helper'

RSpec.describe SummaryLine do
  it { is_expected.to belong_to(:monthly_statement) }
  it { is_expected.to belong_to(:parsed_transaction).class_name('Transaction').optional }
end
