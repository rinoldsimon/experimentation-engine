import { useParams } from "react-router-dom"
import { useExperiment } from "../hooks/useExperiment"
import { ErrorBanner } from "../components/ErrorBanner"
import { ClearCacheButton } from "../components/ClearCacheButton"

/**
 * Generic stand-in demo page for any experiment by name -- so an experiment
 * drafted on the fly with AI (which has no bespoke page like Pricing or
 * Checkout) is still immediately visitable and testable end-to-end.
 */
export default function GenericDemoPage() {
  const { experimentName = "" } = useParams<{ experimentName: string }>()
  const { variantName, content, loading, error, hasConverted, trackConversion } = useExperiment(experimentName)

  return (
    <div className="mx-auto max-w-md space-y-6 text-center">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">{experimentName}</h1>
        <p className="mt-1 text-sm text-slate-500">Generic demo -- shows whatever variant this visitor was assigned.</p>
      </div>

      {loading && <p className="text-slate-500">Loading your assignment…</p>}
      {error && <ErrorBanner message={error} />}

      {!loading && !error && (
        <div className="rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
          <p className="text-xs font-semibold tracking-wide text-indigo-600 uppercase">Variant: {variantName}</p>

          {content ? (
            <p className="mt-4 text-lg font-semibold text-slate-900">{content}</p>
          ) : (
            <p className="mt-4 text-sm text-slate-400 italic">
              No copy configured for this variant yet -- use &ldquo;Generate AI copy&rdquo; on the Dashboard.
            </p>
          )}

          <button
            type="button"
            onClick={() => void trackConversion()}
            disabled={hasConverted}
            className={`mt-6 w-full rounded-md px-4 py-2.5 text-sm font-semibold text-white transition ${
              hasConverted ? "cursor-not-allowed bg-slate-400 opacity-50" : "bg-indigo-600 hover:bg-indigo-700"
            }`}
          >
            {hasConverted ? "Converted ✓" : "Track Conversion"}
          </button>
        </div>
      )}

      <ClearCacheButton />
    </div>
  )
}
