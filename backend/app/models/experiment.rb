class Experiment < ApplicationRecord
  enum :status, { pending: 0, running: 1, stopped: 2 }

  has_many :variants, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
