class Experiment < ApplicationRecord
  # Kill switch: paused bypasses hashing entirely, always serves Control.
  enum :status, { running: 0, paused: 1 }
  # Display-only provenance: which flow created this experiment.
  enum :source, { manual: "manual", ai_draft: "ai_draft" }, default: "manual"

  has_many :variants, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
