const VISITOR_ID_STORAGE_KEY = "visitor_id"

/** Stable anonymous visitor id, persisted in localStorage across page loads. */
export function getVisitorId(): string {
  const existingVisitorId = localStorage.getItem(VISITOR_ID_STORAGE_KEY)
  if (existingVisitorId) {
    return existingVisitorId
  }

  const visitorId = crypto.randomUUID()
  localStorage.setItem(VISITOR_ID_STORAGE_KEY, visitorId)
  return visitorId
}
