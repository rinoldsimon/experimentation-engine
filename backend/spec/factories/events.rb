FactoryBot.define do
  factory :event do
    experiment
    # Explicitly pin the variant to this event's own experiment. Declaring a
    # bare `variant` (like `experiment` above) would let FactoryBot resolve
    # each association independently, building the variant under its own,
    # unrelated experiment instead of the event's.
    variant { association(:variant, experiment: experiment) }
    sequence(:visitor_id) { |n| "visitor-#{n}" }
    event_type { "conversion" }
  end
end
