import type { Experiment, Variant } from "../services/types"

/** Highest-converting variant, or null if there are no conversions yet or it's a tie. */
export function findWinningVariant(experiment: Experiment): Variant | null {
  if (experiment.conversions_count < 1) {
    return null
  }

  const highestRate = Math.max(...experiment.variants.map((variant) => variant.conversion_rate))
  const topVariants = experiment.variants.filter((variant) => variant.conversion_rate === highestRate)

  return topVariants.length === 1 ? topVariants[0] : null
}
