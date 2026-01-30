const dotenv = require("dotenv");

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

try {
  dotenv.config({ path: process.cwd() + "/" + ENV_FILE_NAME });
} catch (e) {}

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
    DATABASE_URL = `postgres://${dbUser}:${dbPassword}@localhost:${process.env.DB_PORT}/${dbName}?host=${process.env.DB_HOST}`;
  } else {
    DATABASE_URL = `postgres://${dbUser}:${dbPassword}@${process.env.DB_HOST}:${process.env.DB_PORT}/${dbName}`;
  }
}

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

const modules = {};

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
  database_extra: process.env.NODE_ENV !== "development" 
    ? (isSocket ? {} : { ssl: { rejectUnauthorized: false } }) 
    : {},
};

/** @type {import('@medusajs/medusa').ConfigModule} */
module.exports = {
  projectConfig,
  plugins,
  modules,
};
