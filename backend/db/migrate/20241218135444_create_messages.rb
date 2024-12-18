class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages do |t|
      t.text :content, null: false
      t.boolean :is_user, default: false
      t.string :message_type, default: 'text'
      t.string :status, default: 'sent'

      t.timestamps
    end

    add_index :messages, :created_at
    add_index :messages, :is_user
  end
end

