const apiUrl = import.meta.env.VITE_API_URL

if (!apiUrl) {
  throw new Error(
    "VITE_API_URL is not set. Copy frontend/.env.example to frontend/.env for local " +
      "development, or configure VITE_API_URL in your deployment platform (e.g. Render).",
  )
}

export const API_BASE_URL = apiUrl

/**
 * Raised whenever a request fails, whether due to a network failure or a
 * non-2xx response from the API. Callers can inspect `status` and `details`
 * to render a meaningful error state in the UI.
 */
export class ApiError extends Error {
  readonly status: number
  readonly details: unknown

  constructor(message: string, status: number, details?: unknown) {
    super(message)
    this.name = "ApiError"
    this.status = status
    this.details = details
  }
}

interface RequestOptions extends Omit<RequestInit, "body"> {
  body?: unknown
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

async function parseResponseBody(response: Response): Promise<unknown> {
  const contentType = response.headers.get("content-type") ?? ""

  if (!contentType.includes("application/json")) {
    return null
  }

  try {
    return await response.json()
  } catch {
    return null
  }
}

function extractErrorMessage(payload: unknown, status: number): string {
  if (isRecord(payload) && typeof payload.error === "string") {
    return payload.error
  }

  if (isRecord(payload) && typeof payload.message === "string") {
    return payload.message
  }

  return `Request failed with status ${status}`
}

/**
 * Centralized fetch wrapper for all API calls. Resolves relative paths
 * against VITE_API_URL, attaches JSON headers, and normalizes both network
 * and HTTP errors into ApiError so callers only need to handle a single
 * error type.
 */
async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { body, headers, ...rest } = options

  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      ...rest,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch (cause) {
    throw new ApiError(
      "Network error: unable to reach the API. Please check your connection and try again.",
      0,
      cause,
    )
  }

  const payload = await parseResponseBody(response)

  if (!response.ok) {
    throw new ApiError(extractErrorMessage(payload, response.status), response.status, payload)
  }

  return payload as T
}

export const api = {
  get: <T>(path: string, options?: RequestOptions) => request<T>(path, { ...options, method: "GET" }),

  post: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "POST", body }),

  put: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "PUT", body }),

  patch: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "PATCH", body }),

  delete: <T>(path: string, options?: RequestOptions) => request<T>(path, { ...options, method: "DELETE" }),
}
