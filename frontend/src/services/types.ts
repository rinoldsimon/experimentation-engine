export type ContentSource = "manual" | "llm" | "llm_fallback"

export interface Variant {
  id: string
  name: string
  weight: number
  // Optional copy, generated once at config time -- see VariantContentGenerator.
  content: string | null
  content_source: ContentSource
  exposures_count: number
  conversions_count: number
  conversion_rate: number
}

export interface Assignment {
  id: string | null
  name: string
  experiment_id: string | null
  content: string | null
  // True only in the rare fail-open case (DB unreachable, no cache to fall back on).
  degraded?: boolean
}

export type ExperimentStatus = "running" | "paused"

export type ExperimentSource = "manual" | "ai_draft"

export interface Experiment {
  id: string
  name: string
  status: ExperimentStatus
  // Which flow created this experiment -- only "ai_draft" ones are deletable from the Dashboard.
  source: ExperimentSource
  variants: Variant[]
  exposures_count: number
  conversions_count: number
  conversion_rate: number
}
