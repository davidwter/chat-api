# app/models/categories_connector.rb
class CategoriesConnector < ApplicationRecord
  belongs_to :category
  belongs_to :connector

  validates :connector_id, uniqueness: { scope: :category_id }
end