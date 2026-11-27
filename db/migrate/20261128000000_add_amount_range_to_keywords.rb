# Optional amount range on keyword rules (and on rule suggestions): "AMAZON" up to R$ 99,99 can
# be a subscription while "AMAZON" from R$ 100 is a purchase. Amounts are absolute values in BRL.
class AddAmountRangeToKeywords < ActiveRecord::Migration[7.1]
  def change
    add_column :keywords, :min_amount, :decimal, precision: 12, scale: 2
    add_column :keywords, :max_amount, :decimal, precision: 12, scale: 2
    add_column :rule_suggestions, :min_amount, :decimal, precision: 12, scale: 2
    add_column :rule_suggestions, :max_amount, :decimal, precision: 12, scale: 2
  end
end
