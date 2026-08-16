import { api } from "./api"
import type { ContentSource } from "./types"

export interface GeneratedContent {
  id: string
  content: string | null
  content_source: ContentSource
}

export function generateVariantContent(variantId: string, prompt: string): Promise<GeneratedContent> {
  return api.patch<GeneratedContent>(`/api/v1/variants/${variantId}/generate_content`, { content_prompt: prompt })
}
