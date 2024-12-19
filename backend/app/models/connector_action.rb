class ConnectorAction < ApplicationRecord
  belongs_to :connector
  validates :name, presence: true, uniqueness: { scope: :connector_id }
end
