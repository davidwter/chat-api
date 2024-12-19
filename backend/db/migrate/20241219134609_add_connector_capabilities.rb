class AddConnectorCapabilities < ActiveRecord::Migration[7.0]
  def change
    create_table :connector_actions do |t|
      t.references :connector, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.json :feature_attributes, default: {}  # Changed from attributes to feature_attributes
      t.timestamps

      t.index [:connector_id, :name], unique: true
    end

    create_table :connector_triggers do |t|
      t.references :connector, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.json :feature_attributes, default: {}  # Changed from attributes to feature_attributes
      t.timestamps

      t.index [:connector_id, :name], unique: true
    end
  end
end
