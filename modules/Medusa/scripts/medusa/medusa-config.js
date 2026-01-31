console.error("DEBUG: Loading medusa-config.js");

// Add process debugging to catch silent exits
process.on('exit', (code) => {
  console.log(`Process exiting with code: ${code}`);
});
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  if (err.code === 'MODULE_NOT_FOUND') {
    console.error('MISSING MODULE:', err.message);
  }
  process.exit(1);
});
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

try {
  // DEBUG LOG
  console.error(">>> LOADING MEDUSA-CONFIG.JS <<<");

  const dotenv = require('dotenv');
  let ENV_FILE_NAME = "";
  switch (process.env.NODE_ENV) {
    case "production":
      ENV_FILE_NAME = ".env.production";
      break;
    case "staging":
      ENV_FILE_NAME = ".env.staging";
      break;
    case "test":
      ENV_FILE_NAME = ".env.test";
      break;
    case "development":
    default:
      ENV_FILE_NAME = ".env";
      break;
  }
  dotenv.config({ path: process.cwd() + "/" + ENV_FILE_NAME });
  console.log("DEBUG: .env loaded for", ENV_FILE_NAME);
} catch (e) {
  console.error("DEBUG: Failed to load .env:", e);
}
console.error("DEBUG: NODE_ENV:", process.env.NODE_ENV);
console.error("DEBUG: CWD:", process.cwd());
try {
  const fs = require('fs');
  console.error("DEBUG: dist exists:", fs.existsSync('./dist'));
  console.error("DEBUG: dist/index.js exists:", fs.existsSync('./dist/index.js'));
} catch (e) { console.error(e); }

// DEBUG: Test requiring modules to find missing dependencies
const dependenciesToTest = [
  "medusa-fulfillment-manual",
  "medusa-payment-manual",
  "@medusajs/file-local",
  "pg",
  "medusa-interfaces"
];

dependenciesToTest.forEach(dep => {
  try {
    require(dep);
    console.error(`DEBUG: Successfully required ${dep}`);
  } catch (err) {
    console.error(`DEBUG: Failed to require ${dep}:`, err.message);
  }
});

// Environment loading moved to top
// try {
//   dotenv.config({ path: process.cwd() + "/" + ENV_FILE_NAME });
// } catch (e) { }

// CORS when consuming Medusa from admin
const ADMIN_CORS = process.env.ADMIN_CORS || "http://localhost:7000,http://localhost:7001";

// CORS to avoid issues when consuming Medusa from a client
const STORE_CORS = process.env.STORE_CORS || "http://localhost:8000";

// Handle Cloud SQL socket connection if DB_HOST starts with /
let DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  const dbUser = encodeURIComponent(process.env.DB_USER);
  const dbPassword = encodeURIComponent(process.env.DB_PASSWORD);
  const dbName = encodeURIComponent(process.env.DB_NAME);

  if (process.env.DB_HOST && process.env.DB_HOST.startsWith("/")) {
    DATABASE_URL = `postgres://${dbUser}:${dbPassword}@localhost:${process.env.DB_PORT}/${dbName}?host=${process.env.DB_HOST}&sslmode=disable`;
  } else {
    debugger; // Ensure we check if we can fall back to socket
    // Attempt to discover socket if DB_HOST is an IP but socket mount exists
    try {
      const socketDir = '/cloudsql';
      if (require('fs').existsSync(socketDir)) {
        console.log(`[DEBUG] Found /cloudsql directory.`);
        const files = require('fs').readdirSync(socketDir);
        console.log(`[DEBUG] /cloudsql contents: ${JSON.stringify(files)}`);
        if (files.length > 0 && !process.env.DB_HOST.startsWith('/')) {
          console.log("[DEBUG] Potential socket available. If IP connection fails, consider using socket.");
          // Optional: Auto-switch to socket if desired, but for now just log.
        }
      } else {
        console.log("[DEBUG] /cloudsql directory NOT found.");
      }
    } catch (e) { console.log("[DEBUG] Error checking /cloudsql:", e.message); }

    DATABASE_URL = `postgres://${dbUser}:${dbPassword}@${process.env.DB_HOST}:${process.env.DB_PORT}/${dbName}?sslmode=disable`;
  }
}

// LOGGING (Masked)
const maskedUrl = DATABASE_URL.replace(/:[^:@]+@/, ":****@");
console.error(`[DEBUG] Configured DATABASE_URL: ${maskedUrl}`);
console.error(`[DEBUG] DB_HOST: ${process.env.DB_HOST}`);

const REDIS_URL = process.env.REDIS_URL;

const plugins = [
  `medusa-fulfillment-manual`,
  `medusa-payment-manual`,
];

if (process.env.MEDUSA_FILE_GOOGLE_BUCKET) {
  plugins.push({
    resolve: `medusa-plugin-file-cloud-storage`,
    options: {
      publicBucketName: process.env.MEDUSA_FILE_GOOGLE_BUCKET,
      privateBucketName: process.env.MEDUSA_FILE_GOOGLE_BUCKET,
    },
  });
} else {
  plugins.push({
    resolve: `@medusajs/file-local`,
    options: {
      upload_dir: "uploads",
    },
  });
}
console.log("Active Plugins:", JSON.stringify(plugins, null, 2));

const modules = {
  eventBus: {
    resolve: "@medusajs/event-bus-local",
  },
  cacheService: {
    resolve: "@medusajs/cache-inmemory",
  },
};

// Check if DB_HOST implies a Unix socket (starts with /)
const isSocket = process.env.DB_HOST && process.env.DB_HOST.startsWith("/");

/** @type {import('@medusajs/medusa').ConfigModule["projectConfig"]} */
const projectConfig = {
  jwt_secret: process.env.JWT_SECRET,
  cookie_secret: process.env.COOKIE_SECRET,
  store_cors: STORE_CORS,
  database_url: DATABASE_URL,
  admin_cors: ADMIN_CORS,
  redis_url: REDIS_URL,
  database_extra: {
    ssl: false,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 30000,
  },
};

console.log("JWT_SECRET provided:", !!process.env.JWT_SECRET);
console.log("COOKIE_SECRET provided:", !!process.env.COOKIE_SECRET);
console.log("DATABASE_URL provided:", !!DATABASE_URL);
console.log("REDIS_URL provided:", !!REDIS_URL);
console.log("PORT:", process.env.PORT);

/** @type {import('@medusajs/medusa').ConfigModule} */
module.exports = {
  projectConfig,
  plugins,
  modules,
};
