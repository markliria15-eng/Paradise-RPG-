const path = require("path");
const dotenv = require("dotenv");

dotenv.config({ path: path.resolve(__dirname, "../.env") });

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

const releaseAndroidDownloadUrl =
  "https://github.com/markliria15-eng/Paradise-RPG-/releases/download/v0.1.5/paradise-rpg-android-v0.1.5.apk";
const legacyPagesAndroidDownloadUrl =
  "https://markliria15-eng.github.io/Paradise-RPG-/downloads/Paradise-RPG.apk";

function androidDownloadUrl() {
  const raw = process.env.ANDROID_APK_URL;
  if (!raw || raw === legacyPagesAndroidDownloadUrl) {
    return releaseAndroidDownloadUrl;
  }
  if (
    raw.includes("/releases/download/v0.1.0/") ||
    raw.includes("/releases/download/v0.1.1/") ||
    raw.includes("/releases/download/v0.1.2/") ||
    raw.includes("/releases/download/v0.1.3/") ||
    raw.includes("/releases/download/v0.1.4/")
  ) {
    return releaseAndroidDownloadUrl;
  }
  return raw;
}

module.exports = {
  env: process.env.NODE_ENV || "development",
  httpHost: process.env.HOST || "0.0.0.0",
  httpPort: intEnv("PORT", 10000),
  wsPort: intEnv("WS_PORT", 8081),
  wsMode: process.env.WS_MODE || "shared",
  wsPath: process.env.WS_PATH || "/ws",
  jwtSecret: process.env.JWT_SECRET || "dev-secret",
  jwtExpires: process.env.JWT_EXPIRES || "7d",
  clientOrigin: process.env.CLIENT_ORIGIN || "*",
  androidDownloadUrl: androidDownloadUrl(),
  db: {
    url: process.env.DATABASE_URL || "",
    ssl: String(process.env.DB_SSL || "").toLowerCase() === "true",
    host: process.env.DB_HOST || "127.0.0.1",
    port: intEnv("DB_PORT", 5432),
    database: process.env.DB_NAME || "arcadia_mmo",
    user: process.env.DB_USER || "arcadia",
    password: process.env.DB_PASSWORD || "arcadia123"
  },
  dbConnectionTimeoutMs: intEnv("DB_CONNECTION_TIMEOUT_MS", 20000),
  dbMigrateAttempts: intEnv("DB_MIGRATE_ATTEMPTS", 8),
  dbMigrateRetryDelayMs: intEnv("DB_MIGRATE_RETRY_DELAY_MS", 5000),
  dbStartupAttempts: intEnv("DB_STARTUP_ATTEMPTS", 8),
  dbStartupRetryDelayMs: intEnv("DB_STARTUP_RETRY_DELAY_MS", 4000),
  saveIntervalMs: intEnv("SAVE_INTERVAL_MS", 20000),
  worldTickMs: intEnv("WORLD_TICK_MS", 100),
  chatFloodWindowMs: intEnv("CHAT_FLOOD_WINDOW_MS", 4000),
  chatFloodMaxMessages: intEnv("CHAT_FLOOD_MAX_MESSAGES", 5)
};
