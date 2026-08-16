import { fireEvent, render, screen, waitFor } from "@testing-library/react"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { DraftExperimentPanel } from "./DraftExperimentPanel"

function mockFetchOnce(body: unknown, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers({ "content-type": "application/json" }),
    json: () => Promise.resolve(body),
  } as Response
}

const DRAFT_RESPONSE = {
  name: "newsletter_signup_cta",
  variants: [
    { name: "control", weight: 50, content: "Subscribe to our newsletter" },
    { name: "urgency", weight: 50, content: "Don't miss out -- subscribe now" },
  ],
}

describe("DraftExperimentPanel", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("starts collapsed, showing only the entry point button", () => {
    render(<DraftExperimentPanel onCreated={vi.fn()} />)

    expect(screen.getByRole("button", { name: /draft a new experiment with ai/i })).toBeInTheDocument()
    expect(screen.queryByPlaceholderText(/increase newsletter signups/i)).not.toBeInTheDocument()
  })

  it("expands into a topic form when clicked", () => {
    render(<DraftExperimentPanel onCreated={vi.fn()} />)

    fireEvent.click(screen.getByRole("button", { name: /draft a new experiment with ai/i }))

    expect(screen.getByPlaceholderText(/increase newsletter signups/i)).toBeInTheDocument()
    expect(screen.getByRole("button", { name: /^draft with ai$/i })).toBeInTheDocument()
  })

  it("drafts a full experiment from a topic and shows an editable review step", async () => {
    vi.mocked(fetch).mockResolvedValueOnce(mockFetchOnce(DRAFT_RESPONSE))

    render(<DraftExperimentPanel onCreated={vi.fn()} />)
    fireEvent.click(screen.getByRole("button", { name: /draft a new experiment with ai/i }))

    fireEvent.change(screen.getByPlaceholderText(/increase newsletter signups/i), {
      target: { value: "Increase newsletter signups" },
    })
    fireEvent.click(screen.getByRole("button", { name: /^draft with ai$/i }))

    await waitFor(() => expect(screen.getByDisplayValue("newsletter_signup_cta")).toBeInTheDocument())

    expect(screen.getByDisplayValue("control")).toBeInTheDocument()
    expect(screen.getByDisplayValue("Subscribe to our newsletter")).toBeInTheDocument()
    expect(screen.getByText(/weights total 100%/i)).toBeInTheDocument()

    const [url, options] = vi.mocked(fetch).mock.calls[0]
    expect(url).toContain("/api/v1/experiment_drafts")
    expect(JSON.parse(options?.body as string)).toEqual({
      topic: "Increase newsletter signups",
      variant_count: 2,
    })
  })

  it("disables Create Experiment while edited weights don't sum to 100", async () => {
    vi.mocked(fetch).mockResolvedValueOnce(mockFetchOnce(DRAFT_RESPONSE))

    render(<DraftExperimentPanel onCreated={vi.fn()} />)
    fireEvent.click(screen.getByRole("button", { name: /draft a new experiment with ai/i }))
    fireEvent.change(screen.getByPlaceholderText(/increase newsletter signups/i), {
      target: { value: "Increase newsletter signups" },
    })
    fireEvent.click(screen.getByRole("button", { name: /^draft with ai$/i }))
    await waitFor(() => expect(screen.getByDisplayValue("newsletter_signup_cta")).toBeInTheDocument())

    fireEvent.change(screen.getAllByDisplayValue("50")[0], { target: { value: "40" } })

    expect(screen.getByText(/must sum to 100 before creating/i)).toBeInTheDocument()
    expect(screen.getByRole("button", { name: /create experiment/i })).toBeDisabled()
  })

  it("creates the reviewed experiment and reports it back via onCreated", async () => {
    const createdExperiment = { id: "exp-1", name: "newsletter_signup_cta", status: "running", variants: [] }
    vi.mocked(fetch)
      .mockResolvedValueOnce(mockFetchOnce(DRAFT_RESPONSE))
      .mockResolvedValueOnce(mockFetchOnce(createdExperiment, 201))
    const onCreated = vi.fn()

    render(<DraftExperimentPanel onCreated={onCreated} />)
    fireEvent.click(screen.getByRole("button", { name: /draft a new experiment with ai/i }))
    fireEvent.change(screen.getByPlaceholderText(/increase newsletter signups/i), {
      target: { value: "Increase newsletter signups" },
    })
    fireEvent.click(screen.getByRole("button", { name: /^draft with ai$/i }))
    await waitFor(() => expect(screen.getByDisplayValue("newsletter_signup_cta")).toBeInTheDocument())

    fireEvent.click(screen.getByRole("button", { name: /create experiment/i }))

    await waitFor(() => expect(onCreated).toHaveBeenCalledWith(createdExperiment))

    const [url, options] = vi.mocked(fetch).mock.calls[1]
    expect(url).toContain("/api/v1/experiments")
    expect(JSON.parse(options?.body as string)).toMatchObject({
      experiment: { name: "newsletter_signup_cta", source: "ai_draft" },
    })

    // Panel resets back to collapsed after a successful create.
    expect(screen.getByRole("button", { name: /draft a new experiment with ai/i })).toBeInTheDocument()
  })

  it("shows an error and returns to the topic form when drafting fails", async () => {
    vi.mocked(fetch).mockResolvedValueOnce(mockFetchOnce({ error: "Topic is required" }, 422))

    render(<DraftExperimentPanel onCreated={vi.fn()} />)
    fireEvent.click(screen.getByRole("button", { name: /draft a new experiment with ai/i }))
    fireEvent.change(screen.getByPlaceholderText(/increase newsletter signups/i), {
      target: { value: "anything" },
    })
    fireEvent.click(screen.getByRole("button", { name: /^draft with ai$/i }))

    await waitFor(() => expect(screen.getByText("Topic is required")).toBeInTheDocument())
    expect(screen.getByPlaceholderText(/increase newsletter signups/i)).toBeInTheDocument()
  })
})
