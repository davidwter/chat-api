class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  validates :status, inclusion: { in: %w[active archived] }

  before_validation :set_default_status

  private

  def set_default_status
    self.status ||= 'active'
  end
end