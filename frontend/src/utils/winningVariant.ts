import type { Experiment, Variant } from "../services/types"

/**
 * The variant with the highest conversion rate within an experiment, or
 * `null` if there's no single winner to declare -- either the experiment
 * doesn't have at least one conversion yet (every variant sits at a 0%
 * rate), or two or more variants are tied for the top rate.
 */
export function findWinningVariant(experiment: Experiment): Variant | null {
  if (experiment.conversions_count < 1) {
    return null
  }

  const highestRate = Math.max(...experiment.variants.map((variant) => variant.conversion_rate))
  const topVariants = experiment.variants.filter((variant) => variant.conversion_rate === highestRate)

  return topVariants.length === 1 ? topVariants[0] : null
}
