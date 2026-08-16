import { api } from "./api"
import type { Experiment } from "./types"

export function fetchExperiments(): Promise<Experiment[]> {
  return api.get<Experiment[]>("/api/v1/experiments")
}

export function toggleExperimentStatus(experimentId: string): Promise<Experiment> {
  return api.patch<Experiment>(`/api/v1/experiments/${experimentId}/toggle_status`)
}
