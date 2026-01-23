import { withPayload } from '@payloadcms/next/withPayload'

/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['@payloadcms/db-postgres', 'sharp'],
  },
  output: 'standalone',
}

export default withPayload(nextConfig)
