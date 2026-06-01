const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const morgan = require("morgan");

const config = require("./config");
const logger = require("./utils/logger");
const pool = require("./db/pool");
const authRoutes = require("./http/authRoutes");
const WorldService = require("./services/worldService");
const WsGateway = require("./net/wsGateway");

async function main() {
  await pool.query("SELECT 1");
  logger.info("Banco conectado.");

  const app = express();
  app.use(helmet());
  app.use(compression());
  app.use(cors({ origin: config.clientOrigin }));
  app.use(express.json({ limit: "256kb" }));
  app.use(morgan("dev"));

  app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "arcadia-mmo-server", at: new Date().toISOString() });
  });
  app.use("/auth", authRoutes);

  app.listen(config.httpPort, () => {
    logger.info(`HTTP online em http://127.0.0.1:${config.httpPort}`);
  });

  const world = new WorldService();
  await world.bootstrapMmoSystems();
  const ws = new WsGateway({
    port: config.wsPort,
    worldService: world
  });
  ws.start();
  logger.info(`WebSocket MMO online em ws://127.0.0.1:${config.wsPort}`);

  setInterval(async () => {
    try {
      await world.tick();
    } catch (err) {
      logger.error("Erro no tick do mundo", err);
    }
  }, config.worldTickMs);
}

main().catch((err) => {
  logger.error("Falha fatal ao subir servidor", err);
  process.exit(1);
});
