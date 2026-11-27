# The owner's own explanation for a correction ("this PIX is my rent"), given in the
# re-categorize dialog. Sent to Claude as context for similar transactions.
class AddNoteToCategorizationEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :categorization_events, :note, :string, limit: 300
  end
end
