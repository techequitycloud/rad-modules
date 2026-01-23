import {defineConfig} from 'sanity'
import {structureTool} from 'sanity/structure'
import {visionTool} from '@sanity/vision'
import {schemaTypes} from './schema'

// Define the shape of our injected configuration
interface SanityConfig {
  projectId: string
  dataset: string
}

// Access the injected configuration from window
// We cast window to any to avoid TypeScript errors about missing properties
const config = ((typeof window !== 'undefined' ? (window as any).SANITY_CONFIG : null) || {}) as SanityConfig

export default defineConfig({
  name: 'default',
  title: 'Sanity Studio',

  projectId: config.projectId || 'placeholder-project-id',
  dataset: config.dataset || 'production',

  plugins: [structureTool(), visionTool()],

  schema: {
    types: schemaTypes,
  },
})
