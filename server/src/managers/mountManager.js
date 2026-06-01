const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");

class MountManager {
  constructor() {
    this.definitions = loadProjectJson("data/mmo_mounts.json");
  }

  async bootstrapDefinitions() {
    for (const mount of this.definitions) {
      await mmoRepo.upsertMountDefinition({
        code: mount.code,
        name: mount.name,
        rarity: mount.rarity,
        speedBonus: mount.speed_bonus,
        extraBonus: mount.extra_bonus
      });
    }
  }

  async list(characterId) {
    let rows = await mmoRepo.listCharacterMounts(characterId);
    if (rows.length === 0 && this.definitions.length > 0) {
      await this.grant(characterId, this.definitions[0].code);
      rows = await mmoRepo.listCharacterMounts(characterId);
    }
    return rows;
  }

  async grant(characterId, mountCode) {
    await mmoRepo.grantMountByCode(characterId, mountCode);
    return this.list(characterId);
  }

  async equip(characterId, characterMountId, context = { inCombat: false, inDungeon: false }) {
    if (context.inCombat) {
      throw new Error("Nao pode montar durante combate.");
    }
    if (context.inDungeon) {
      throw new Error("Nao pode montar dentro de dungeon.");
    }
    await mmoRepo.setMountEquipped(characterId, characterMountId);
    return this.list(characterId);
  }

  async unequip(characterId) {
    await mmoRepo.setMountEquipped(characterId, -1);
    return this.list(characterId);
  }
}

module.exports = MountManager;
