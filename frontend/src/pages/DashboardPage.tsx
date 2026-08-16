import { useCallback, useEffect, useRef, useState } from "react"
import { Link } from "react-router-dom"
import { ApiError } from "../services/api"
import { deleteExperiment, fetchExperiments, toggleExperimentStatus } from "../services/experiments"
import { generateVariantContent, type GeneratedContent } from "../services/variants"
import type { Experiment, Variant } from "../services/types"
import { ErrorBanner } from "../components/ErrorBanner"
import { DraftExperimentPanel } from "../components/DraftExperimentPanel"
import { findWinningVariant } from "../utils/winningVariant"

// The two showcase experiments have bespoke demo pages; anything else
// (e.g. AI-drafted experiments) falls back to the generic /demo/:name page.
const BESPOKE_DEMO_PATHS: Record<string, string> = {
  pricing_plan_default: "/demo/pricing",
  checkout_upsell_placement: "/demo/checkout",
}

function demoPathFor(experimentName: string): string {
  return BESPOKE_DEMO_PATHS[experimentName] ?? `/demo/${experimentName}`
}

function formatPercent(rate: number): string {
  return `${(rate * 100).toFixed(1)}%`
}

export default function DashboardPage() {
  const [experiments, setExperiments] = useState<Experiment[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [togglingId, setTogglingId] = useState<string | null>(null)
  // Mirrors togglingId without retriggering the poll effect below on every toggle click.
  const isTogglingRef = useRef(false)

  const loadExperiments = useCallback(() => {
    setError(null)
    fetchExperiments()
      .then(setExperiments)
      .catch((err: unknown) => setError(err instanceof ApiError ? err.message : "Failed to load experiments"))
  }, [])

  // Polling keeps this in sync with events tracked from another tab; skipped
  // mid-toggle so a poll can't clobber that update in flight.
  useEffect(() => {
    loadExperiments()

    const intervalId = window.setInterval(() => {
      if (!isTogglingRef.current) loadExperiments()
    }, 5000)

    return () => window.clearInterval(intervalId)
  }, [loadExperiments])

  async function handleToggle(experiment: Experiment) {
    setTogglingId(experiment.id)
    isTogglingRef.current = true
    try {
      const updated = await toggleExperimentStatus(experiment.id)
      setExperiments((current) => current?.map((exp) => (exp.id === updated.id ? updated : exp)) ?? current)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to update experiment status")
    } finally {
      setTogglingId(null)
      isTogglingRef.current = false
    }
  }

  function handleExperimentCreated(experiment: Experiment) {
    setExperiments((current) => [...(current ?? []), experiment])
  }

  async function handleDelete(experiment: Experiment) {
    if (!window.confirm(`Delete "${experiment.name}"? This removes all its variants and tracked events.`)) return

    try {
      await deleteExperiment(experiment.id)
      setExperiments((current) => current?.filter((exp) => exp.id !== experiment.id) ?? current)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to delete experiment")
    }
  }

  function handleContentGenerated(variantId: string, generated: GeneratedContent) {
    setExperiments(
      (current) =>
        current?.map((exp) => ({
          ...exp,
          variants: exp.variants.map((variant) =>
            variant.id === variantId
              ? { ...variant, content: generated.content, content_source: generated.content_source }
              : variant,
          ),
        })) ?? current,
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">Experiments</h1>
        <p className="mt-1 text-sm text-slate-500">Monitor live experiments and pause any of them instantly.</p>
      </div>

      {!error && experiments && <DraftExperimentPanel onCreated={handleExperimentCreated} />}

      {error && <ErrorBanner message={error} onRetry={loadExperiments} />}

      {!error && !experiments && <p className="text-slate-500">Loading experiments…</p>}

      {!error && experiments && experiments.length === 0 && (
        <p className="rounded-lg border border-slate-200 bg-white p-6 text-slate-500">
          No experiments yet. Draft one with AI above, or run{" "}
          <code className="rounded bg-slate-100 px-1.5 py-0.5">bin/rails db:seed</code> to create some.
        </p>
      )}

      {!error && experiments && experiments.length > 0 && (
        <div className="space-y-6">
          {experiments.map((experiment) => (
            <ExperimentCard
              key={experiment.id}
              experiment={experiment}
              isToggling={togglingId === experiment.id}
              onToggle={() => handleToggle(experiment)}
              onDelete={() => handleDelete(experiment)}
              onContentGenerated={handleContentGenerated}
            />
          ))}
        </div>
      )}
    </div>
  )
}

interface ExperimentCardProps {
  experiment: Experiment
  isToggling: boolean
  onToggle: () => void
  onDelete: () => void
  onContentGenerated: (variantId: string, generated: GeneratedContent) => void
}

function ExperimentCard({ experiment, isToggling, onToggle, onDelete, onContentGenerated }: ExperimentCardProps) {
  const winner = findWinningVariant(experiment)

  return (
    <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3">
        <div className="flex items-center gap-3">
          <h2 className="font-semibold text-slate-900">{experiment.name}</h2>
          <StatusBadge status={experiment.status} />
          {experiment.source === "ai_draft" && (
            <span
              title="Created by Gemini via the Draft with AI panel"
              className="inline-flex items-center gap-1 rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-700"
            >
              🤖 AI-drafted
            </span>
          )}
          <Link to={demoPathFor(experiment.name)} className="text-xs font-medium text-indigo-600 hover:text-indigo-700">
            Try it →
          </Link>
        </div>

        <div className="flex items-center gap-4">
          <span className="text-xs text-slate-500">
            {experiment.exposures_count} exposures · {experiment.conversions_count} conversions ·{" "}
            {formatPercent(experiment.conversion_rate)} overall
          </span>
          <button
            type="button"
            onClick={onToggle}
            disabled={isToggling}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold text-white transition disabled:cursor-not-allowed disabled:opacity-50 ${
              experiment.status === "running" ? "bg-amber-600 hover:bg-amber-700" : "bg-emerald-600 hover:bg-emerald-700"
            }`}
          >
            {isToggling ? "…" : experiment.status === "running" ? "Pause" : "Resume"}
          </button>
          {experiment.source === "ai_draft" && (
            <button
              type="button"
              onClick={onDelete}
              title="Delete experiment"
              className="rounded-md px-2 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50"
            >
              Delete
            </button>
          )}
        </div>
      </div>

      <table className="w-full text-left text-sm">
        <thead className="text-xs uppercase tracking-wide text-slate-500">
          <tr>
            <th className="px-4 py-2 font-medium">Variant</th>
            <th className="px-4 py-2 font-medium">Weight</th>
            <th className="px-4 py-2 text-right font-medium">Exposures</th>
            <th className="px-4 py-2 text-right font-medium">Conversions</th>
            <th className="px-4 py-2 text-right font-medium">Conv. Rate</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {experiment.variants.map((variant) => (
            <VariantRow
              key={variant.id}
              variant={variant}
              isWinner={winner?.id === variant.id}
              onContentGenerated={onContentGenerated}
            />
          ))}
        </tbody>
      </table>
    </div>
  )
}

interface VariantRowProps {
  variant: Variant
  isWinner: boolean
  onContentGenerated: (variantId: string, generated: GeneratedContent) => void
}

function VariantRow({ variant, isWinner, onContentGenerated }: VariantRowProps) {
  return (
    <tr className={isWinner ? "bg-emerald-50" : undefined}>
      <td className="px-4 py-2.5 text-slate-700">
        <div className="flex items-center gap-2">
          <span className={isWinner ? "font-semibold text-emerald-700" : undefined}>{variant.name}</span>
          {isWinner && (
            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700">
              🏆 Winner
            </span>
          )}
        </div>
        {variant.content && (
          <div className="mt-0.5 flex items-center gap-1 text-xs text-slate-500 italic">
            {variant.content_source === "llm" && <span title="AI-generated by Gemini">🤖</span>}
            <span>&ldquo;{variant.content}&rdquo;</span>
          </div>
        )}
        <GenerateContentControl variant={variant} onGenerated={onContentGenerated} />
      </td>
      <td className="px-4 py-2.5 text-slate-600">{variant.weight}%</td>
      <td className="px-4 py-2.5 text-right text-slate-600">{variant.exposures_count}</td>
      <td className="px-4 py-2.5 text-right text-slate-600">{variant.conversions_count}</td>
      <td className="px-4 py-2.5 text-right text-slate-600">{formatPercent(variant.conversion_rate)}</td>
    </tr>
  )
}

interface GenerateContentControlProps {
  variant: Variant
  onGenerated: (variantId: string, generated: GeneratedContent) => void
}

/** Inline "Generate AI copy" control -- calls the live Gemini-backed endpoint on demand, so the LLM integration is visibly working from the UI, not just in the seed data. */
function GenerateContentControl({ variant, onGenerated }: GenerateContentControlProps) {
  const [expanded, setExpanded] = useState(false)
  const [prompt, setPrompt] = useState("")
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleGenerate() {
    if (!prompt.trim()) return

    setGenerating(true)
    setError(null)
    try {
      const generated = await generateVariantContent(variant.id, prompt.trim())
      onGenerated(variant.id, generated)
      setExpanded(false)
      setPrompt("")
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to generate content")
    } finally {
      setGenerating(false)
    }
  }

  if (!expanded) {
    return (
      <button
        type="button"
        onClick={() => setExpanded(true)}
        className="mt-1 text-xs font-medium text-indigo-600 hover:text-indigo-700"
      >
        ✨ Generate AI copy
      </button>
    )
  }

  return (
    <div className="mt-1.5 flex items-start gap-1.5">
      <input
        type="text"
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && handleGenerate()}
        placeholder={`e.g. a short headline for "${variant.name}"`}
        disabled={generating}
        autoFocus
        className="w-64 rounded-md border border-slate-300 px-2 py-1 text-xs text-slate-700 focus:border-indigo-500 focus:outline-none disabled:opacity-50"
      />
      <button
        type="button"
        onClick={handleGenerate}
        disabled={generating || !prompt.trim()}
        className="rounded-md bg-indigo-600 px-2.5 py-1 text-xs font-semibold text-white hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {generating ? "Asking Gemini…" : "Generate"}
      </button>
      <button
        type="button"
        onClick={() => {
          setExpanded(false)
          setError(null)
        }}
        disabled={generating}
        className="rounded-md px-2 py-1 text-xs text-slate-400 hover:text-slate-600"
      >
        Cancel
      </button>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  )
}

function StatusBadge({ status }: { status: Experiment["status"] }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
        status === "running" ? "bg-emerald-100 text-emerald-700" : "bg-amber-100 text-amber-700"
      }`}
    >
      {status}
    </span>
  )
}
