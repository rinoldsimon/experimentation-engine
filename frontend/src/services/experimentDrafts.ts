import { api } from "./api"

export interface DraftVariant {
  name: string
  weight: number
  content: string
}

export interface ExperimentDraft {
  name: string
  variants: DraftVariant[]
}

/** Asks the LLM to draft a full experiment from a topic. Never persists anything -- see DESIGN.md "The LLM decision". */
export function draftExperiment(topic: string, variantCount: number): Promise<ExperimentDraft> {
  return api.post<ExperimentDraft>("/api/v1/experiment_drafts", { topic, variant_count: variantCount })
}
