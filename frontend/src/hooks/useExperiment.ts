import { useCallback, useEffect, useState } from "react"
import { ApiError } from "../services/api"
import { fetchAssignment } from "../services/assignments"
import { trackEvent } from "../services/events"
import type { Assignment } from "../services/types"
import { getVisitorId } from "../utils/visitor"
import { hasConverted, markConverted } from "../utils/conversionFlag"

interface UseExperimentResult {
  variantName: string | null
  content: string | null
  loading: boolean
  error: string | null
  hasConverted: boolean
  trackConversion: () => Promise<void>
}

/**
 * Fetches this visitor's sticky assignment for `experimentName`, and exposes
 * `trackConversion` to report a conversion against it.
 */
export function useExperiment(experimentName: string): UseExperimentResult {
  const [assignment, setAssignment] = useState<Assignment | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [converted, setConverted] = useState(() => hasConverted(experimentName))

  useEffect(() => {
    let isMounted = true
    const visitorId = getVisitorId()

    setLoading(true)
    setError(null)
    setConverted(hasConverted(experimentName))

    fetchAssignment(experimentName, visitorId)
      .then((result) => {
        if (isMounted) setAssignment(result)
      })
      .catch((err: unknown) => {
        if (!isMounted) return
        setError(err instanceof ApiError ? err.message : "Failed to load experiment assignment")
      })
      .finally(() => {
        if (isMounted) setLoading(false)
      })

    return () => {
      isMounted = false
    }
  }, [experimentName])

  const trackConversion = useCallback(async () => {
    // No-op in the degraded/fail-open case -- there's no real variant id to attribute to.
    if (!assignment || assignment.degraded || !assignment.experiment_id || !assignment.id) return

    await trackEvent({
      experiment_id: assignment.experiment_id,
      variant_id: assignment.id,
      visitor_id: getVisitorId(),
      event_type: "conversion",
    })

    markConverted(experimentName)
    setConverted(true)
  }, [assignment, experimentName])

  return {
    variantName: assignment?.name ?? null,
    content: assignment?.content ?? null,
    loading,
    error,
    hasConverted: converted,
    trackConversion,
  }
}
