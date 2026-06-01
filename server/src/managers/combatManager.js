class CombatManager {
  constructor({ pvpManager, entityManager }) {
    this.pvpManager = pvpManager;
    this.entityManager = entityManager;
  }

  _rollDamage(base, defense) {
    const variance = Math.floor(Math.random() * 6) - 2;
    return Math.max(1, base + variance - defense);
  }

  attackPlayer(attacker, defender, context = { power: 1.0, baseAttack: 12 }) {
    const allow = this.pvpManager.canAttack(attacker, defender);
    if (!allow.ok) return { ok: false, reason: allow.reason };
    const raw = this._rollDamage(Math.floor(context.baseAttack * context.power), Math.floor(defender.level * 0.4));
    defender.hp = Math.max(0, defender.hp - raw);
    this.pvpManager.tagCombat(attacker, defender);
    return { ok: true, damage: raw, targetHp: defender.hp };
  }

  attackBoss(attacker, bossId, context = { power: 1.0, baseAttack: 12 }) {
    const boss = this.entityManager.getBoss(bossId);
    if (!boss) return { ok: false, reason: "boss_not_found" };
    if (attacker.map !== boss.map) return { ok: false, reason: "different_map" };
    const damage = this._rollDamage(Math.floor(context.baseAttack * context.power), boss.defense);
    boss.hp = Math.max(0, boss.hp - damage);
    boss.contribution[attacker.characterId] = (boss.contribution[attacker.characterId] || 0) + damage;
    return { ok: true, damage, boss };
  }
}

module.exports = CombatManager;

