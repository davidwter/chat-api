class Message < ApplicationRecord
  validates :content, presence: true
  validates :message_type, inclusion: { in: %w[text system error] }
  validates :status, inclusion: { in: %w[sending sent failed] }

  # Scopes for easy querying
  scope :user_messages, -> { where(is_user: true) }
  scope :bot_messages, -> { where(is_user: false) }
  scope :by_type, ->(type) { where(message_type: type) }

  def as_json(options = {})
    super(options).merge({
                           id: id.to_s,
                           timestamp: created_at.to_i * 1000 # Convert to milliseconds for JavaScript
                         })
  end
end
