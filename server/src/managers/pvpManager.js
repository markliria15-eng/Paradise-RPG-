class PvpManager {
  constructor(mapManager) {
    this.mapManager = mapManager;
    this.combatTag = new Map();
  }

  canAttack(attacker, defender) {
    if (!attacker || !defender) return { ok: false, reason: "player_missing" };
    if (attacker.map !== defender.map) return { ok: false, reason: "different_map" };
    if (!this.mapManager.isPvpEnabled(attacker.map)) return { ok: false, reason: "pvp_disabled_map" };
    if (attacker.level <= 10 || defender.level <= 10) return { ok: false, reason: "newbie_protection" };
    return { ok: true };
  }

  tagCombat(a, b) {
    const now = Date.now();
    this.combatTag.set(a.characterId, now);
    this.combatTag.set(b.characterId, now);
  }
}

module.exports = PvpManager;

