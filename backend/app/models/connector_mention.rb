class ConnectorMention < ApplicationRecord
  belongs_to :message
  belongs_to :connector
end
