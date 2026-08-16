class Variant < ApplicationRecord
  belongs_to :experiment

  has_many :events, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :experiment_id }
  validates :weight, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
