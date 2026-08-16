import { api } from "./api"

export interface CreateEventPayload {
  experiment_id: string
  variant_id: string
  visitor_id: string
  event_type: string
}

export interface TrackEventResult {
  id: string | null
  // false when the event was a duplicate, or the experiment is paused.
  tracked: boolean
}

export function trackEvent(payload: CreateEventPayload): Promise<TrackEventResult> {
  return api.post<TrackEventResult>("/api/v1/events", payload)
}
