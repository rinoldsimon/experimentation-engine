class Event < ApplicationRecord
  belongs_to :experiment
  belongs_to :variant, optional: true

  validates :visitor_id, presence: true
  validates :event_type, presence: true

  # A matching unique DB index is the real guarantee under concurrent requests.
  validates :visitor_id, uniqueness: { scope: [ :experiment_id, :event_type ] }
end
