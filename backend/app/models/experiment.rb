class Experiment < ApplicationRecord
  # A simple two-state kill switch: experiments are either serving traffic
  # (running) or bypassed entirely in favor of the Control variant (paused).
  enum :status, { running: 0, paused: 1 }

  has_many :variants, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
