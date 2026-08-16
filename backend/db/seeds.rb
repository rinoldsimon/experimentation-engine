# Resets local experiment data to two realistic product experiments, with
# zero events, so the frontend's tracking (exposures/conversions) can be
# verified manually from a clean slate. This is destructive by design -- see
# the README's "Local Development" and "Production Deployment" notes before
# running this outside of a throwaway dev database.
Experiment.destroy_all

[
  {
    name: "pricing_plan_default",
    status: :running,
    variants: [
      { name: "monthly_default", weight: 50 },
      { name: "annual_default", weight: 50 }
    ]
  },
  {
    name: "checkout_upsell_placement",
    status: :running,
    # Three-way split (rather than an even 50/50) so the Dashboard visibly
    # demonstrates that variant weights don't have to be equal, as long as
    # they sum to 100.
    variants: [
      { name: "header_banner", weight: 34 },
      { name: "cart_inline", weight: 33 },
      { name: "sticky_footer", weight: 33 }
    ]
  }
].each do |experiment_attrs|
  experiment = Experiment.create!(
    name: experiment_attrs[:name],
    status: experiment_attrs[:status]
  )

  experiment_attrs[:variants].each do |variant_attrs|
    experiment.variants.create!(variant_attrs)
  end

  puts "Seeded experiment: #{experiment.name} (#{experiment.variants.pluck(:name).join(', ')})"
end
