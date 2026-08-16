import { useState } from "react"
import { useExperiment } from "../hooks/useExperiment"
import { ErrorBanner } from "../components/ErrorBanner"
import { ClearCacheButton } from "../components/ClearCacheButton"

const PRICING_PLAN_EXPERIMENT = "pricing_plan_default"

const PLAN_COPY: Record<string, { label: string; price: string; cadence: string }> = {
  monthly_default: { label: "Monthly plan", price: "$19", cadence: "/mo" },
  annual_default: { label: "Annual plan", price: "$190", cadence: "/yr" },
}

export default function PricingDemoPage() {
  const { variantName, loading, error, hasConverted, trackConversion } = useExperiment(PRICING_PLAN_EXPERIMENT)
  const [subscribing, setSubscribing] = useState(false)

  async function handleSubscribe() {
    if (hasConverted) return

    setSubscribing(true)
    try {
      await trackConversion()
    } finally {
      setSubscribing(false)
    }
  }

  const plan = variantName ? PLAN_COPY[variantName] : undefined
  const subscribeDisabled = subscribing || hasConverted || !plan

  return (
    <div className="mx-auto max-w-md space-y-6 text-center">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">Choose your plan</h1>
        <p className="mt-1 text-sm text-slate-500">
          This pricing card is driven live by the <code className="text-slate-700">{PRICING_PLAN_EXPERIMENT}</code>{" "}
          experiment.
        </p>
      </div>

      {loading && <p className="text-slate-500">Loading your plan…</p>}
      {error && <ErrorBanner message={error} />}

      {!loading && !error && (
        <div className="rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
          {plan ? (
            <>
              <p className="text-xs font-semibold tracking-wide text-indigo-600 uppercase">{plan.label}</p>
              <p className="mt-2 text-4xl font-bold text-slate-900">
                {plan.price}
                <span className="text-lg font-medium text-slate-500">{plan.cadence}</span>
              </p>
            </>
          ) : (
            <p className="text-slate-500">Unrecognized variant: {variantName}</p>
          )}

          <button
            type="button"
            onClick={handleSubscribe}
            disabled={subscribeDisabled}
            className={`mt-6 w-full rounded-md px-4 py-2.5 text-sm font-semibold text-white transition ${
              subscribeDisabled ? "cursor-not-allowed bg-slate-400 opacity-50" : "bg-indigo-600 hover:bg-indigo-700"
            }`}
          >
            {hasConverted ? "Already Subscribed" : subscribing ? "Subscribing…" : "Subscribe"}
          </button>
        </div>
      )}

      <ClearCacheButton />
    </div>
  )
}
