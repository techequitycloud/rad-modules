#!/usr/bin/env node

/**
 * Database Initialization Script for Payload CMS
 *
 * This script initializes the Payload database before the main server starts.
 * It runs migrations via prodMigrations configured in payload.config.ts.
 * This follows the recommended approach from Payload CMS documentation.
 */

import { getPayload } from 'payload'
import config from './payload.config.js'

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
    console.log(`  Environment: ${process.env.NODE_ENV || 'development'}`)

    // Initialize Payload - this will run prodMigrations in production
    console.log('')
    console.log('Initializing Payload (migrations will run automatically)...')
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

    console.log('')
    console.log('✅ Database initialization complete!')
    console.log('')

    process.exit(0)
  } catch (error) {
    console.error('')
    console.error('❌ Database initialization failed:', error)
    console.error('')
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      ...(error.stack && { stack: error.stack })
    })
    console.error('')
    process.exit(1)
  }
}

// Run initialization
initDatabase()
