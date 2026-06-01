class EventManager {
  constructor({ onBroadcast, bossManager }) {
    this.onBroadcast = onBroadcast;
    this.bossManager = bossManager;
    this.lastDoubleXpAt = 0;
    this.lastBossAt = 0;
  }

  tick(nowMs) {
    const every15m = 15 * 60 * 1000;
    const every20m = 20 * 60 * 1000;

    if (nowMs - this.lastDoubleXpAt > every15m) {
      this.lastDoubleXpAt = nowMs;
      this.onBroadcast({
        type: "system_event",
        event: "double_xp",
        text: "Evento global: XP dobrado por 5 minutos!"
      });
    }

    if (nowMs - this.lastBossAt > every20m) {
      this.lastBossAt = nowMs;
      const boss = this.bossManager.spawnSkeletonKing("arcane_ruins");
      this.onBroadcast({
        type: "system_event",
        event: "boss_spawn",
        text: "Boss Rei Esqueleto apareceu nas Ruinas Arcanas!",
        boss
      });
    }
  }
}

module.exports = EventManager;

