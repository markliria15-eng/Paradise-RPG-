class EntityManager {
  constructor() {
    this.bosses = new Map();
  }

  spawnBoss(boss) {
    this.bosses.set(boss.id, boss);
    return boss;
  }

  removeBoss(bossId) {
    this.bosses.delete(bossId);
  }

  listBossesByMap(mapId) {
    return [...this.bosses.values()].filter((b) => b.map === mapId);
  }

  getBoss(bossId) {
    return this.bosses.get(bossId) || null;
  }
}

module.exports = EntityManager;

