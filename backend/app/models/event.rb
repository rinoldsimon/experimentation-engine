class Event < ApplicationRecord
  belongs_to :experiment
  belongs_to :variant, optional: true

  validates :visitor_id, presence: true
  validates :event_type, presence: true

  # Backed by a matching unique DB index -- this validation gives a friendly
  # in-app check, while the index is the real guarantee against duplicate
  # exposures/conversions under concurrent requests.
  validates :visitor_id, uniqueness: { scope: [ :experiment_id, :event_type ] }
end
