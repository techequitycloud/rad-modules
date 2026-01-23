#!/usr/bin/env node

/**
 * Database Initialization Script for Payload CMS
 *
 * This script initializes the Payload database schema before the main server starts.
 * It ensures all tables are created using Payload's push:true mechanism.
 */

import { getPayload } from 'payload'
import { postgresAdapter } from '@payloadcms/db-postgres'
import { lexicalEditor } from '@payloadcms/richtext-lexical'
import { buildConfig } from 'payload'
import { en } from 'payload/i18n/en'

const initDatabase = async () => {
  console.log('🚀 Initializing Payload CMS database...')

  try {
    // Validate required environment variables
    const requiredEnvVars = ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'PAYLOAD_SECRET']
    const missingVars = requiredEnvVars.filter(varName => !process.env[varName])

    if (missingVars.length > 0) {
      throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`)
    }

    console.log('✓ Environment variables validated')
    console.log(`  Database: ${process.env.DB_NAME}`)
    console.log(`  Host: ${process.env.DB_HOST}:${process.env.DB_PORT}`)
    console.log(`  User: ${process.env.DB_USER}`)

    // Build Payload configuration inline
    const config = buildConfig({
      admin: {
        user: 'users',
      },
      editor: lexicalEditor({}),
      collections: [
        {
          slug: 'users',
          auth: true,
          access: {
            delete: () => false,
            update: () => false,
          },
          fields: [],
        },
        {
          slug: 'media',
          upload: {
            staticDir: '/app/media',
            disableLocalStorage: false,
          },
          fields: [
            {
              name: 'alt',
              type: 'text',
            },
          ],
        },
      ],
      secret: process.env.PAYLOAD_SECRET || 'YOUR_SECRET_HERE',
      db: postgresAdapter({
        push: true,
        pool: {
          connectionString: process.env.DATABASE_URI || `postgres://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
        },
      }),
      i18n: {
        supportedLanguages: { en },
      },
    })

    // Initialize Payload - this will trigger the schema push
    console.log('Connecting to Payload and pushing database schema...')
    const payload = await getPayload({
      config,
    })

    console.log('✓ Payload initialized successfully')

    // Verify database connection by checking collections
    const collections = Object.keys(payload.collections)
    console.log(`✓ Found ${collections.length} collections: ${collections.join(', ')}`)

    // Check if we can query the database
    try {
      const userCount = await payload.count({
        collection: 'users',
      })
      console.log(`✓ Database query successful (${userCount.totalDocs} users)`)
    } catch (queryError) {
      // If this is a fresh database, the tables might just have been created
      console.log('⚠ Initial query failed (expected for new database):', queryError.message)
    }

    console.log('✅ Database initialization complete!')
    console.log('')

    process.exit(0)
  } catch (error) {
    console.error('❌ Database initialization failed:', error)
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    })
    process.exit(1)
  }
}

// Run initialization
initDatabase()
