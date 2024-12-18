class CreateConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :conversations do |t|
      t.string :title
      t.string :status, default: 'active'
      t.timestamps
    end

    add_reference :messages, :conversation, foreign_key: true
    add_index :conversations, :created_at
    add_index :conversations, :status
  end
end