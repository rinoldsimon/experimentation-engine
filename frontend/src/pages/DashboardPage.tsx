import { useCallback, useEffect, useState } from "react"
import { ApiError } from "../services/api"
import { fetchExperiments, toggleExperimentStatus } from "../services/experiments"
import type { Experiment, Variant } from "../services/types"
import { ErrorBanner } from "../components/ErrorBanner"
import { findWinningVariant } from "../utils/winningVariant"

function formatPercent(rate: number): string {
  return `${(rate * 100).toFixed(1)}%`
}

export default function DashboardPage() {
  const [experiments, setExperiments] = useState<Experiment[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [togglingId, setTogglingId] = useState<string | null>(null)

  const loadExperiments = useCallback(() => {
    setError(null)
    fetchExperiments()
      .then(setExperiments)
      .catch((err: unknown) => setError(err instanceof ApiError ? err.message : "Failed to load experiments"))
  }, [])

  useEffect(() => {
    loadExperiments()
  }, [loadExperiments])

  async function handleToggle(experiment: Experiment) {
    setTogglingId(experiment.id)
    try {
      const updated = await toggleExperimentStatus(experiment.id)
      setExperiments((current) => current?.map((exp) => (exp.id === updated.id ? updated : exp)) ?? current)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to update experiment status")
    } finally {
      setTogglingId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">Experiments</h1>
        <p className="mt-1 text-sm text-slate-500">Monitor live experiments and pause any of them instantly.</p>
      </div>

      {error && <ErrorBanner message={error} onRetry={loadExperiments} />}

      {!error && !experiments && <p className="text-slate-500">Loading experiments…</p>}

      {!error && experiments && experiments.length === 0 && (
        <p className="rounded-lg border border-slate-200 bg-white p-6 text-slate-500">
          No experiments yet. Run <code className="rounded bg-slate-100 px-1.5 py-0.5">bin/rails db:seed</code> to
          create some.
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
}

function ExperimentCard({ experiment, isToggling, onToggle }: ExperimentCardProps) {
  const winner = findWinningVariant(experiment)

  return (
    <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3">
        <div className="flex items-center gap-3">
          <h2 className="font-semibold text-slate-900">{experiment.name}</h2>
          <StatusBadge status={experiment.status} />
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
            <VariantRow key={variant.id} variant={variant} isWinner={winner?.id === variant.id} />
          ))}
        </tbody>
      </table>
    </div>
  )
}

interface VariantRowProps {
  variant: Variant
  isWinner: boolean
}

function VariantRow({ variant, isWinner }: VariantRowProps) {
  return (
    <tr className={isWinner ? "bg-emerald-50" : undefined}>
      <td className="px-4 py-2.5 text-slate-700">
        <span className={isWinner ? "font-semibold text-emerald-700" : undefined}>{variant.name}</span>
        {isWinner && (
          <span className="ml-2 inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700">
            🏆 Winner
          </span>
        )}
      </td>
      <td className="px-4 py-2.5 text-slate-600">{variant.weight}%</td>
      <td className="px-4 py-2.5 text-right text-slate-600">{variant.exposures_count}</td>
      <td className="px-4 py-2.5 text-right text-slate-600">{variant.conversions_count}</td>
      <td className="px-4 py-2.5 text-right text-slate-600">{formatPercent(variant.conversion_rate)}</td>
    </tr>
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
