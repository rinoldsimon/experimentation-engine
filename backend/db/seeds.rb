# Destructive (wipes all experiments/variants/events) -- see README's
# "Database Seeding" notes before running outside a throwaway dev DB.
# Goes through ExperimentCreationService, the same path as the Configuration
# API, so this also doubles as a smoke test for it.
Experiment.destroy_all

[
  {
    name: "pricing_plan_default",
    status: "running",
    variants: [
      { name: "monthly_default", weight: 50, content: "Monthly plan" },
      { name: "annual_default", weight: 50, content: "Annual plan" }
    ]
  },
  {
    name: "checkout_upsell_placement",
    status: "running",
    # 34/33/33 split to show weights don't need to be even. Content here is
    # plain hardcoded copy (content_source: "manual", the default) -- seed
    # data shouldn't look AI-generated. Try "✨ Generate AI copy" on the
    # Dashboard against any of these to regenerate it live via Gemini instead;
    # only variants generated that way earn the 🤖 badge.
    variants: [
      { name: "header_banner", weight: 34, content: "Free shipping on all orders!" },
      { name: "cart_inline", weight: 33, content: "Free shipping" },
      { name: "sticky_footer", weight: 33, content: "Free shipping unlocked -- sticking with you through checkout!" }
    ]
  }
].each do |experiment_attrs|
  experiment = ExperimentCreationService.call(**experiment_attrs)

  variant_summaries = experiment.variants.map { |variant| "#{variant.name} (#{variant.content_source})" }
  puts "Seeded experiment: #{experiment.name} (#{variant_summaries.join(', ')})"
end
