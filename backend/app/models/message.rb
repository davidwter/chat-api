class Message < ApplicationRecord
  belongs_to :conversation

  validates :content, presence: true
  validates :message_type, inclusion: { in: %w[text system error] }
  validates :status, inclusion: { in: %w[sending sent failed] }

  before_validation :set_defaults

  private

  def set_defaults
    self.message_type ||= 'text'
    self.status ||= 'sent'
  end
end