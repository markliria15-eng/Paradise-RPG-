const { v4: uuidv4 } = require("uuid");

class BossManager {
  constructor(entityManager) {
    this.entityManager = entityManager;
  }

  spawnSkeletonKing(map = "arcane_ruins") {
    const boss = {
      id: uuidv4(),
      code: "skeleton_king",
      name: "Rei Esqueleto",
      map,
      pos: { x: 1100, y: 720 },
      maxHp: 15000,
      hp: 15000,
      attack: 120,
      defense: 60,
      contribution: {},
      spawnedAt: Date.now()
    };
    return this.entityManager.spawnBoss(boss);
  }

  tryFinalizeDeadBoss() {
    const dead = [];
    for (const boss of this.entityManager.bosses.values()) {
      if (boss.hp <= 0) {
        dead.push(boss);
        this.entityManager.removeBoss(boss.id);
      }
    }
    return dead;
  }
}

module.exports = BossManager;

