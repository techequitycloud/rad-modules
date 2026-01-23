import {defineConfig} from 'sanity'
import {structureTool} from 'sanity/structure'
import {visionTool} from '@sanity/vision'
import {schemaTypes} from './schema'

// Define the shape of our injected configuration
interface SanityConfig {
  projectId: string
  dataset: string
}

// Hybrid configuration approach:
// 1. Try runtime injection via window.SANITY_CONFIG (for Docker reusability)
// 2. Fall back to Sanity's native env vars (statically replaced at build time)
// 3. Final fallback to placeholder

const runtimeConfig = ((typeof window !== 'undefined' ? (window as any).SANITY_CONFIG : null) || {}) as SanityConfig

// Use runtime config if available, otherwise use Sanity's native env vars
// Note: process.env.SANITY_STUDIO_PROJECT_ID is statically replaced during build
const projectId = runtimeConfig.projectId || process.env.SANITY_STUDIO_PROJECT_ID || 'placeholder-project-id'
const dataset = runtimeConfig.dataset || process.env.SANITY_STUDIO_DATASET || 'production'

export default defineConfig({
  name: 'default',
  title: 'Sanity Studio',

  projectId: projectId,
  dataset: dataset,

  plugins: [structureTool(), visionTool()],

  schema: {
    types: schemaTypes,
  },
})
