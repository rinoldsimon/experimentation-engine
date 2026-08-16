function storageKey(experimentName: string): string {
  return `converted_${experimentName}`
}

/**
 * Whether this browser has already recorded a conversion for
 * `experimentName`, persisted in localStorage so demo pages can keep
 * "Subscribe"/"Complete Checkout" buttons disabled across reloads until the
 * visitor clears their cache.
 */
export function hasConverted(experimentName: string): boolean {
  return localStorage.getItem(storageKey(experimentName)) === "true"
}

export function markConverted(experimentName: string): void {
  localStorage.setItem(storageKey(experimentName), "true")
}
