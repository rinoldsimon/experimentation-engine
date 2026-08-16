// Wipes the persisted visitor id so the next request looks like a new visitor.
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
