const VISITOR_ID_STORAGE_KEY = "visitor_id"

/**
 * Returns a stable, anonymous id for this browser, persisting it in
 * localStorage so the same visitor keeps the same id (and therefore the
 * same deterministic experiment assignment) across page loads and sessions.
 */
export function getVisitorId(): string {
  const existingVisitorId = localStorage.getItem(VISITOR_ID_STORAGE_KEY)
  if (existingVisitorId) {
    return existingVisitorId
  }

  const visitorId = crypto.randomUUID()
  localStorage.setItem(VISITOR_ID_STORAGE_KEY, visitorId)
  return visitorId
}
