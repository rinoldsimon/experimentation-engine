import { api } from "./api"
import type { Assignment } from "./types"

export function fetchAssignment(experimentName: string, visitorId: string): Promise<Assignment> {
  const query = new URLSearchParams({ experiment_name: experimentName, visitor_id: visitorId })
  return api.get<Assignment>(`/api/v1/assignments?${query.toString()}`)
}
