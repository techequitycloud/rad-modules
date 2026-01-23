import { RootLayout, handleServerFunctions } from '@payloadcms/next/layouts'
import React from 'react'
import configPromise from '@payload-config'
import { importMap } from './admin/importMap'

/* This layout wraps all pages */
const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <RootLayout
    config={configPromise}
    importMap={importMap}
    serverFunction={async (args) => {
      'use server'
      return handleServerFunctions({
        ...args,
        config: configPromise,
        importMap,
      })
    }}
  >
    {children}
  </RootLayout>
)

export default Layout
