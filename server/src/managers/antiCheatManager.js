class AntiCheatManager {
  constructor() {
    this.lastPositions = new Map();
  }

  validateMove(characterId, nextPos, nowMs, maxSpeedPerSec = 260) {
    const prev = this.lastPositions.get(characterId);
    if (!prev) {
      this.lastPositions.set(characterId, { pos: nextPos, at: nowMs });
      return { ok: true };
    }
    const dt = Math.max(1, nowMs - prev.at);
    const maxDist = (maxSpeedPerSec * dt) / 1000.0 + 32;
    const dx = nextPos.x - prev.pos.x;
    const dy = nextPos.y - prev.pos.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > maxDist) {
      return { ok: false, reason: "speed_or_teleport_hack" };
    }
    this.lastPositions.set(characterId, { pos: nextPos, at: nowMs });
    return { ok: true };
  }

  clear(characterId) {
    this.lastPositions.delete(characterId);
  }
}

module.exports = AntiCheatManager;

