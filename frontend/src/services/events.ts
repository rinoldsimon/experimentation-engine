import { api } from "./api"

export interface CreateEventPayload {
  experiment_id: string
  variant_id: string
  visitor_id: string
  event_type: string
}

export interface TrackEventResult {
  id: string | null
  // false when the event wasn't newly recorded -- either it was a duplicate
  // of an existing event, or the experiment is paused (see EventsController,
  // which mirrors AssignmentsController's kill switch: no exposure gets
  // logged while paused, so no conversion should either).
  tracked: boolean
}

export function trackEvent(payload: CreateEventPayload): Promise<TrackEventResult> {
  return api.post<TrackEventResult>("/api/v1/events", payload)
}
