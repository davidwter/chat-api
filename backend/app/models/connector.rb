# app/models/connector.rb
class Connector < ApplicationRecord
  has_many :categories_connectors, dependent: :destroy
  has_many :categories, through: :categories_connectors
  has_many :connector_mentions, dependent: :destroy
  has_many :messages, through: :connector_mentions

  validates :name, presence: true, uniqueness: true
end

# app/models/category.rb
class Category < ApplicationRecord
  has_many :categories_connectors, dependent: :destroy
  has_many :connectors, through: :categories_connectors

  validates :name, presence: true, uniqueness: true
end

# app/models/categories_connector.rb
class CategoriesConnector < ApplicationRecord
  belongs_to :connector
  belongs_to :category

  validates :connector_id, uniqueness: { scope: :category_id }
end

# app/models/connector_mention.rb
class ConnectorMention < ApplicationRecord
  belongs_to :message
  belongs_to :connector

  validates :message_id, uniqueness: { scope: :connector_id }
  validates :confidence_score,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            },
            allow_nil: true
end