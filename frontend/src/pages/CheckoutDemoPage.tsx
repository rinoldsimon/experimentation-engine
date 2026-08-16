import { useState } from "react"
import { useExperiment } from "../hooks/useExperiment"
import { ErrorBanner } from "../components/ErrorBanner"
import { ClearCacheButton } from "../components/ClearCacheButton"

const CHECKOUT_UPSELL_EXPERIMENT = "checkout_upsell_placement"

const MOCK_CART_ITEMS = [
  { name: "Wireless Headphones", price: "$79.00" },
  { name: "Charging Cable", price: "$12.00" },
]
const MOCK_CART_TOTAL = "$91.00"

export default function CheckoutDemoPage() {
  const { variantName, content, loading, error, hasConverted, trackConversion } =
    useExperiment(CHECKOUT_UPSELL_EXPERIMENT)
  const [checkingOut, setCheckingOut] = useState(false)

  async function handleCompleteCheckout() {
    if (hasConverted) return

    setCheckingOut(true)
    try {
      await trackConversion()
    } finally {
      setCheckingOut(false)
    }
  }

  const showHeaderBanner = variantName === "header_banner"
  const showInlineShipping = variantName === "cart_inline"
  const showStickyFooter = variantName === "sticky_footer"
  const checkoutDisabled = checkingOut || hasConverted

  return (
    <div className={`mx-auto max-w-md space-y-6 ${showStickyFooter ? "pb-16" : ""}`}>
      {showHeaderBanner && (
        <div className="rounded-lg bg-emerald-600 px-4 py-2 text-center text-sm font-semibold text-white">
          🚚 {content ?? "Free shipping on all orders!"}
        </div>
      )}

      <div className="text-center">
        <h1 className="text-2xl font-semibold text-slate-900">Your cart</h1>
        <p className="mt-1 text-sm text-slate-500">
          This checkout mock is driven live by the{" "}
          <code className="text-slate-700">{CHECKOUT_UPSELL_EXPERIMENT}</code> experiment.
        </p>
      </div>

      {loading && <p className="text-center text-slate-500">Loading your cart…</p>}
      {error && <ErrorBanner message={error} />}

      {!loading && !error && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <ul className="divide-y divide-slate-100">
            {MOCK_CART_ITEMS.map((item) => (
              <li key={item.name} className="flex items-center justify-between py-3 text-sm">
                <span className="text-slate-700">{item.name}</span>
                <span className="font-medium text-slate-900">{item.price}</span>
              </li>
            ))}
          </ul>

          <div className="mt-3 flex items-center justify-between border-t border-slate-100 pt-3 text-sm font-semibold text-slate-900">
            <span>Total</span>
            <span>{MOCK_CART_TOTAL}</span>
          </div>

          <div className="mt-6 flex items-center gap-3">
            <button
              type="button"
              onClick={handleCompleteCheckout}
              disabled={checkoutDisabled}
              className={`flex-1 rounded-md px-4 py-2.5 text-sm font-semibold text-white transition ${
                checkoutDisabled ? "cursor-not-allowed bg-slate-400 opacity-50" : "bg-indigo-600 hover:bg-indigo-700"
              }`}
            >
              {hasConverted ? "Order Placed" : checkingOut ? "Placing order…" : "Complete Checkout"}
            </button>

            {showInlineShipping && (
              <span className="text-xs font-semibold whitespace-nowrap text-emerald-600">
                🚚 {content ?? "Free shipping"}
              </span>
            )}
          </div>
        </div>
      )}

      <div className="text-center">
        <ClearCacheButton />
      </div>

      {showStickyFooter && (
        <div className="fixed inset-x-0 bottom-0 z-10 bg-emerald-600 px-4 py-3 text-center text-sm font-semibold text-white shadow-lg">
          🚚 {content ?? "Free shipping unlocked — sticking with you through checkout!"}
        </div>
      )}
    </div>
  )
}
