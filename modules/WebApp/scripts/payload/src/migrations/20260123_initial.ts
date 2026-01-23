import { MigrateUpArgs, MigrateDownArgs, sql } from '@payloadcms/db-postgres'

/**
 * Initial migration for Payload CMS
 * Creates the base schema for users and media collections
 */

export async function up({ payload, req }: MigrateUpArgs): Promise<void> {
  await payload.db.drizzle.execute(sql`
    -- Create users table
    CREATE TABLE IF NOT EXISTS "users" (
      "id" serial PRIMARY KEY NOT NULL,
      "updated_at" timestamp(3) with time zone DEFAULT now() NOT NULL,
      "created_at" timestamp(3) with time zone DEFAULT now() NOT NULL,
      "email" varchar NOT NULL,
      "reset_password_token" varchar,
      "reset_password_expiration" timestamp(3) with time zone,
      "salt" varchar,
      "hash" varchar,
      "login_attempts" numeric DEFAULT 0,
      "lock_until" timestamp(3) with time zone
    );

    CREATE UNIQUE INDEX IF NOT EXISTS "users_email_idx" ON "users" ("email");
    CREATE INDEX IF NOT EXISTS "users_created_at_idx" ON "users" ("created_at");

    -- Create media table
    CREATE TABLE IF NOT EXISTS "media" (
      "id" serial PRIMARY KEY NOT NULL,
      "alt" varchar,
      "updated_at" timestamp(3) with time zone DEFAULT now() NOT NULL,
      "created_at" timestamp(3) with time zone DEFAULT now() NOT NULL,
      "url" varchar,
      "thumbnail_u_r_l" varchar,
      "filename" varchar,
      "mime_type" varchar,
      "filesize" numeric,
      "width" numeric,
      "height" numeric,
      "focal_x" numeric,
      "focal_y" numeric
    );

    CREATE INDEX IF NOT EXISTS "media_created_at_idx" ON "media" ("created_at");
    CREATE INDEX IF NOT EXISTS "media_filename_idx" ON "media" ("filename");

    -- Create payload_preferences table (used by Payload for user preferences)
    CREATE TABLE IF NOT EXISTS "payload_preferences" (
      "id" serial PRIMARY KEY NOT NULL,
      "key" varchar,
      "value" jsonb,
      "updated_at" timestamp(3) with time zone DEFAULT now() NOT NULL,
      "created_at" timestamp(3) with time zone DEFAULT now() NOT NULL
    );

    CREATE INDEX IF NOT EXISTS "payload_preferences_key_idx" ON "payload_preferences" ("key");
    CREATE INDEX IF NOT EXISTS "payload_preferences_created_at_idx" ON "payload_preferences" ("created_at");

    -- Create payload_preferences_rels table (relationship table)
    CREATE TABLE IF NOT EXISTS "payload_preferences_rels" (
      "id" serial PRIMARY KEY NOT NULL,
      "order" integer,
      "parent_id" integer NOT NULL,
      "path" varchar NOT NULL,
      "users_id" integer
    );

    CREATE INDEX IF NOT EXISTS "payload_preferences_rels_order_idx" ON "payload_preferences_rels" ("order");
    CREATE INDEX IF NOT EXISTS "payload_preferences_rels_parent_idx" ON "payload_preferences_rels" ("parent_id");
    CREATE INDEX IF NOT EXISTS "payload_preferences_rels_path_idx" ON "payload_preferences_rels" ("path");

    -- Create payload_migrations table (used by Payload to track migrations)
    CREATE TABLE IF NOT EXISTS "payload_migrations" (
      "id" serial PRIMARY KEY NOT NULL,
      "name" varchar,
      "batch" numeric,
      "updated_at" timestamp(3) with time zone DEFAULT now() NOT NULL,
      "created_at" timestamp(3) with time zone DEFAULT now() NOT NULL
    );

    CREATE INDEX IF NOT EXISTS "payload_migrations_created_at_idx" ON "payload_migrations" ("created_at");

    -- Add foreign key constraints
    DO $$ BEGIN
      ALTER TABLE "payload_preferences_rels" ADD CONSTRAINT "payload_preferences_rels_parent_fk"
        FOREIGN KEY ("parent_id") REFERENCES "payload_preferences"("id") ON DELETE cascade ON UPDATE no action;
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;

    DO $$ BEGIN
      ALTER TABLE "payload_preferences_rels" ADD CONSTRAINT "payload_preferences_rels_users_fk"
        FOREIGN KEY ("users_id") REFERENCES "users"("id") ON DELETE cascade ON UPDATE no action;
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;
  `);
}

export async function down({ payload, req }: MigrateDownArgs): Promise<void> {
  await payload.db.drizzle.execute(sql`
    DROP TABLE IF EXISTS "payload_preferences_rels" CASCADE;
    DROP TABLE IF EXISTS "payload_preferences" CASCADE;
    DROP TABLE IF EXISTS "payload_migrations" CASCADE;
    DROP TABLE IF EXISTS "media" CASCADE;
    DROP TABLE IF EXISTS "users" CASCADE;
  `);
}
