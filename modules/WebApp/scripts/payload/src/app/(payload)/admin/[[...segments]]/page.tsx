import type { Metadata } from 'next'

import configPromise from '@payload-config'
import { RootPage, generatePageMetadata } from '@payloadcms/next/views'
import { importMap } from '../../../../importMap'

const Page = ({ params, searchParams }: { params: Promise<{ segments: string[] }>; searchParams: Promise<{ [key: string]: string | string[] }> }) => (
  <RootPage config={configPromise} params={params} searchParams={searchParams} importMap={importMap} />
)

export default Page

export const generateMetadata = ({ params, searchParams }: { params: Promise<{ segments: string[] }>; searchParams: Promise<{ [key: string]: string | string[] }> }): Promise<Metadata> =>
  generatePageMetadata({ config: configPromise, params, searchParams })
