class CreateConnectorStructure < ActiveRecord::Migration[7.0]
  def change
    # Main connectors table
    create_table :connectors do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps

      t.index :name, unique: true
    end

    # Categories table
    create_table :categories do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps

      t.index :name, unique: true
    end

    # Join table for connectors and categories (many-to-many)
    create_table :categories_connectors do |t|
      t.references :connector, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps

      t.index [:connector_id, :category_id], unique: true
    end

    # Connector mentions for tracking usage in messages
    create_table :connector_mentions do |t|
      t.references :message, null: false, foreign_key: true
      t.references :connector, null: false, foreign_key: true
      t.decimal :confidence_score, precision: 5, scale: 2  # Allows scores from 0.00 to 999.99
      t.timestamps

      t.index [:message_id, :connector_id], unique: true
      t.index :confidence_score  # Useful for filtering/analyzing by confidence
    end
  end
end
