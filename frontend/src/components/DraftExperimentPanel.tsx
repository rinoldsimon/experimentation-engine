import { useState } from "react"
import { ApiError } from "../services/api"
import { draftExperiment, type DraftVariant } from "../services/experimentDrafts"
import { createExperiment } from "../services/experiments"
import type { Experiment } from "../services/types"

type Step = "idle" | "drafting" | "reviewing" | "creating"

interface DraftExperimentPanelProps {
  onCreated: (experiment: Experiment) => void
}

/** "Give a topic, get a runnable experiment" -- drafts via Gemini, but always leaves a human to review/edit before anything is actually created. */
export function DraftExperimentPanel({ onCreated }: DraftExperimentPanelProps) {
  const [expanded, setExpanded] = useState(false)
  const [topic, setTopic] = useState("")
  const [variantCount, setVariantCount] = useState(2)
  const [step, setStep] = useState<Step>("idle")
  const [error, setError] = useState<string | null>(null)
  const [draftName, setDraftName] = useState("")
  const [draftVariants, setDraftVariants] = useState<DraftVariant[]>([])

  function reset() {
    setExpanded(false)
    setTopic("")
    setVariantCount(2)
    setStep("idle")
    setError(null)
    setDraftName("")
    setDraftVariants([])
  }

  async function handleDraft() {
    if (!topic.trim()) return

    setStep("drafting")
    setError(null)
    try {
      const draft = await draftExperiment(topic.trim(), variantCount)
      setDraftName(draft.name)
      setDraftVariants(draft.variants)
      setStep("reviewing")
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to draft an experiment")
      setStep("idle")
    }
  }

  async function handleCreate() {
    setStep("creating")
    setError(null)
    try {
      const experiment = await createExperiment({ name: draftName, source: "ai_draft", variants: draftVariants })
      onCreated(experiment)
      reset()
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to create the experiment")
      setStep("reviewing")
    }
  }

  function updateVariant(index: number, patch: Partial<DraftVariant>) {
    setDraftVariants((current) => current.map((variant, i) => (i === index ? { ...variant, ...patch } : variant)))
  }

  if (!expanded) {
    return (
      <button
        type="button"
        onClick={() => setExpanded(true)}
        className="w-full rounded-lg border border-dashed border-indigo-300 bg-indigo-50/50 px-4 py-3 text-sm font-medium text-indigo-700 hover:bg-indigo-100"
      >
        ✨ Draft a new experiment with AI
      </button>
    )
  }

  const weightTotal = draftVariants.reduce((sum, variant) => sum + variant.weight, 0)
  const isReviewing = step === "reviewing" || step === "creating"

  return (
    <div className="rounded-lg border border-indigo-200 bg-indigo-50/40 p-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-indigo-900">✨ Draft a new experiment with AI</h3>
        <button type="button" onClick={reset} className="text-xs text-slate-400 hover:text-slate-600">
          Close
        </button>
      </div>

      {!isReviewing && (
        <div className="mt-3 flex flex-wrap items-end gap-2">
          <div className="min-w-64 flex-1">
            <label className="block text-xs font-medium text-slate-600">What do you want to test?</label>
            <input
              type="text"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleDraft()}
              placeholder="e.g. Increase newsletter signups on the blog homepage"
              disabled={step === "drafting"}
              autoFocus
              className="mt-1 w-full rounded-md border border-slate-300 px-2.5 py-1.5 text-sm focus:border-indigo-500 focus:outline-none disabled:opacity-50"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-600">Variants</label>
            <input
              type="number"
              min={2}
              max={5}
              value={variantCount}
              onChange={(e) => setVariantCount(Number(e.target.value))}
              disabled={step === "drafting"}
              className="mt-1 w-16 rounded-md border border-slate-300 px-2 py-1.5 text-sm focus:border-indigo-500 focus:outline-none disabled:opacity-50"
            />
          </div>
          <button
            type="button"
            onClick={handleDraft}
            disabled={step === "drafting" || !topic.trim()}
            className="rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {step === "drafting" ? "Asking Gemini…" : "Draft with AI"}
          </button>
        </div>
      )}

      {isReviewing && (
        <div className="mt-3 space-y-3">
          <p className="text-xs text-slate-500">Review and edit before creating -- nothing is live yet.</p>

          <div>
            <label className="block text-xs font-medium text-slate-600">Experiment name</label>
            <input
              type="text"
              value={draftName}
              onChange={(e) => setDraftName(e.target.value)}
              disabled={step === "creating"}
              className="mt-1 w-full rounded-md border border-slate-300 px-2.5 py-1.5 font-mono text-sm focus:border-indigo-500 focus:outline-none disabled:opacity-50"
            />
          </div>

          <div className="space-y-2">
            {draftVariants.map((variant, index) => (
              <div key={index} className="grid grid-cols-[7rem_4rem_1fr] gap-2 rounded-md bg-white p-2 ring-1 ring-slate-200">
                <input
                  type="text"
                  value={variant.name}
                  onChange={(e) => updateVariant(index, { name: e.target.value })}
                  disabled={step === "creating"}
                  className="rounded border border-slate-200 px-2 py-1 text-xs font-mono focus:border-indigo-500 focus:outline-none disabled:opacity-50"
                />
                <input
                  type="number"
                  value={variant.weight}
                  onChange={(e) => updateVariant(index, { weight: Number(e.target.value) })}
                  disabled={step === "creating"}
                  className="rounded border border-slate-200 px-2 py-1 text-xs focus:border-indigo-500 focus:outline-none disabled:opacity-50"
                />
                <input
                  type="text"
                  value={variant.content}
                  onChange={(e) => updateVariant(index, { content: e.target.value })}
                  disabled={step === "creating"}
                  className="rounded border border-slate-200 px-2 py-1 text-xs focus:border-indigo-500 focus:outline-none disabled:opacity-50"
                />
              </div>
            ))}
            <p className={`text-xs ${weightTotal === 100 ? "text-slate-500" : "font-semibold text-red-600"}`}>
              Weights total {weightTotal}%{weightTotal !== 100 && " -- must sum to 100 before creating"}
            </p>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleCreate}
              disabled={step === "creating" || weightTotal !== 100 || !draftName.trim()}
              className="rounded-md bg-emerald-600 px-3 py-1.5 text-sm font-semibold text-white hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {step === "creating" ? "Creating…" : "Create Experiment"}
            </button>
            <button
              type="button"
              onClick={() => setStep("idle")}
              disabled={step === "creating"}
              className="rounded-md px-3 py-1.5 text-sm text-slate-500 hover:text-slate-700"
            >
              Back
            </button>
          </div>
        </div>
      )}

      {error && <p className="mt-2 text-xs font-medium text-red-600">{error}</p>}
    </div>
  )
}
