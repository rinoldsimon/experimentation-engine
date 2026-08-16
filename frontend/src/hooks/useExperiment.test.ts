import { act, renderHook, waitFor } from "@testing-library/react"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { useExperiment } from "./useExperiment"

vi.mock("../utils/visitor", () => ({
  getVisitorId: () => "visitor-123",
}))

const EXPERIMENT_NAME = "pricing_plan_default"

function mockFetchOnce(body: unknown, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers({ "content-type": "application/json" }),
    json: () => Promise.resolve(body),
  } as Response
}

describe("useExperiment", () => {
  beforeEach(() => {
    localStorage.clear()
    vi.stubGlobal("fetch", vi.fn())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("fetches the assignment and returns the variant name and content once loaded", async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      mockFetchOnce({ id: "variant-1", name: "monthly_default", experiment_id: "exp-1", content: "Save 20% yearly" }),
    )

    const { result } = renderHook(() => useExperiment(EXPERIMENT_NAME))

    expect(result.current.loading).toBe(true)
    expect(result.current.variantName).toBeNull()

    await waitFor(() => expect(result.current.loading).toBe(false))

    expect(result.current.variantName).toBe("monthly_default")
    expect(result.current.content).toBe("Save 20% yearly")
    expect(result.current.error).toBeNull()
    expect(result.current.hasConverted).toBe(false)

    const [url, options] = vi.mocked(fetch).mock.calls[0]
    expect(url).toContain("/api/v1/assignments?")
    expect(url).toContain(`experiment_name=${EXPERIMENT_NAME}`)
    expect(url).toContain("visitor_id=visitor-123")
    expect(options).toMatchObject({ method: "GET" })
  })

  it("sets an error and stops loading when the assignment fetch fails", async () => {
    vi.mocked(fetch).mockResolvedValueOnce(mockFetchOnce({ error: "Experiment not found" }, 404))

    const { result } = renderHook(() => useExperiment(EXPERIMENT_NAME))

    await waitFor(() => expect(result.current.loading).toBe(false))

    expect(result.current.error).toBe("Experiment not found")
    expect(result.current.variantName).toBeNull()
  })

  it("reads hasConverted from localStorage on mount, before any network call resolves", async () => {
    localStorage.setItem(`converted_${EXPERIMENT_NAME}`, "true")
    vi.mocked(fetch).mockResolvedValueOnce(
      mockFetchOnce({ id: "variant-1", name: "monthly_default", experiment_id: "exp-1" }),
    )

    const { result } = renderHook(() => useExperiment(EXPERIMENT_NAME))

    expect(result.current.hasConverted).toBe(true)
    await waitFor(() => expect(result.current.loading).toBe(false))
    expect(result.current.hasConverted).toBe(true)
  })

  it("trackConversion posts a conversion event and persists hasConverted", async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(mockFetchOnce({ id: "variant-1", name: "monthly_default", experiment_id: "exp-1" }))
      .mockResolvedValueOnce(mockFetchOnce({ id: "event-1", tracked: true }, 201))

    const { result } = renderHook(() => useExperiment(EXPERIMENT_NAME))
    await waitFor(() => expect(result.current.loading).toBe(false))

    await act(async () => {
      await result.current.trackConversion()
    })

    expect(result.current.hasConverted).toBe(true)
    expect(localStorage.getItem(`converted_${EXPERIMENT_NAME}`)).toBe("true")

    const [url, options] = vi.mocked(fetch).mock.calls[1]
    expect(url).toContain("/api/v1/events")
    expect(options).toMatchObject({ method: "POST" })
    expect(JSON.parse(options?.body as string)).toEqual({
      experiment_id: "exp-1",
      variant_id: "variant-1",
      visitor_id: "visitor-123",
      event_type: "conversion",
    })
  })

  it("trackConversion is a no-op for a degraded (fail-open) assignment", async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      mockFetchOnce({ id: null, name: "control", experiment_id: null, degraded: true }),
    )

    const { result } = renderHook(() => useExperiment(EXPERIMENT_NAME))
    await waitFor(() => expect(result.current.loading).toBe(false))

    await act(async () => {
      await result.current.trackConversion()
    })

    // Only the initial assignment fetch happened -- no events call, since
    // there's no real experiment/variant id to attribute a conversion to.
    expect(fetch).toHaveBeenCalledTimes(1)
    expect(result.current.hasConverted).toBe(false)
  })
})
