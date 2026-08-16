FactoryBot.define do
  factory :variant do
    experiment
    sequence(:name) { |n| "Variant #{n}" }
    weight { 50 }
  end
end
