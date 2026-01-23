import { RootLayout } from '@payloadcms/next/layouts'
import React from 'react'

/* This layout wraps all pages */
const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <RootLayout>{children}</RootLayout>
)

export default Layout
