# app/models/category.rb
class Category < ApplicationRecord
  has_many :categories_connectors, dependent: :destroy
  has_many :connectors, through: :categories_connectors

  validates :name, presence: true, uniqueness: true
end