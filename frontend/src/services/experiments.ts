import { api } from "./api"
import type { Experiment } from "./types"

export interface CreateExperimentVariantPayload {
  name: string
  weight: number
  content?: string
}

export interface CreateExperimentPayload {
  name: string
  source?: "manual" | "ai_draft"
  variants: CreateExperimentVariantPayload[]
}

export function fetchExperiments(): Promise<Experiment[]> {
  return api.get<Experiment[]>("/api/v1/experiments")
}

export function createExperiment(payload: CreateExperimentPayload): Promise<Experiment> {
  return api.post<Experiment>("/api/v1/experiments", { experiment: payload })
}

export function toggleExperimentStatus(experimentId: string): Promise<Experiment> {
  return api.patch<Experiment>(`/api/v1/experiments/${experimentId}/toggle_status`)
}

export function deleteExperiment(experimentId: string): Promise<void> {
  return api.delete<void>(`/api/v1/experiments/${experimentId}`)
}
