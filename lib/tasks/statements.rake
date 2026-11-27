namespace :statements do
  desc "Set statement_kind on statements imported before it was recorded, by re-detecting each file's layout"
  task backfill_kind: :environment do
    MonthlyStatement.where(statement_kind: nil).find_each do |statement|
      next unless statement.file.attached?

      kind = MonthlyStatements::KindDetector.call(statement)
      statement.update_columns(statement_kind: kind) if kind
      puts "Statement #{statement.id}: #{kind || 'unknown'}"
    end
  end
end
