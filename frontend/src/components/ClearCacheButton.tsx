// Wipes the persisted visitor id (and anything else stored locally) so the
// next assignment request is indistinguishable from a brand new visitor.
function handleClearCacheAndReload() {
  localStorage.clear()
  window.location.reload()
}

export function ClearCacheButton() {
  return (
    <button
      type="button"
      onClick={handleClearCacheAndReload}
      className="text-sm font-medium text-slate-500 underline hover:text-slate-700"
    >
      Clear Cache &amp; Reload (simulate a new visitor)
    </button>
  )
}
