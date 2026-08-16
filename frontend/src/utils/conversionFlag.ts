function storageKey(experimentName: string): string {
  return `converted_${experimentName}`
}

/** Whether this browser already converted for `experimentName` (persisted in localStorage). */
export function hasConverted(experimentName: string): boolean {
  return localStorage.getItem(storageKey(experimentName)) === "true"
}

export function markConverted(experimentName: string): void {
  localStorage.setItem(storageKey(experimentName), "true")
}
