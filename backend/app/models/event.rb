class Event < ApplicationRecord
  belongs_to :experiment
  belongs_to :variant, optional: true

  validates :visitor_id, presence: true
  validates :event_type, presence: true
end
