export interface Variant {
  id: string
  name: string
  weight: number
  exposures_count: number
  conversions_count: number
  conversion_rate: number
}

export interface Assignment {
  id: string
  name: string
  experiment_id: string
}

export type ExperimentStatus = "running" | "paused"

export interface Experiment {
  id: string
  name: string
  status: ExperimentStatus
  variants: Variant[]
  exposures_count: number
  conversions_count: number
  conversion_rate: number
}
