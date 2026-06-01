const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");

class PetManager {
  constructor() {
    this.definitions = loadProjectJson("data/mmo_pets.json");
  }

  async bootstrapDefinitions() {
    for (const pet of this.definitions) {
      await mmoRepo.upsertPetDefinition({
        code: pet.code,
        name: pet.name,
        rarity: pet.rarity,
        baseBonus: pet.base_bonus
      });
    }
  }

  async list(characterId) {
    let rows = await mmoRepo.listCharacterPets(characterId);
    if (rows.length === 0 && this.definitions.length > 0) {
      await this.grant(characterId, this.definitions[0].code);
      rows = await mmoRepo.listCharacterPets(characterId);
    }
    return rows;
  }

  async grant(characterId, petCode) {
    await mmoRepo.grantPetByCode(characterId, petCode);
    return this.list(characterId);
  }

  async equip(characterId, characterPetId) {
    await mmoRepo.setPetEquipped(characterId, characterPetId);
    return this.list(characterId);
  }

  xpRequired(level) {
    return 100 + level * 35;
  }

  async grantKillXp(characterId, deltaXp) {
    const pets = await this.list(characterId);
    const equipped = pets.find((p) => p.equipped);
    if (!equipped) return null;
    const gained = Math.max(1, Math.floor(deltaXp * 0.1));
    let xp = Number(equipped.xp) + gained;
    let level = Number(equipped.level);
    const messages = [];
    while (xp >= this.xpRequired(level)) {
      xp -= this.xpRequired(level);
      level += 1;
      messages.push(`${equipped.name} subiu para o nivel ${level}!`);
    }
    await mmoRepo.updatePetLevel(equipped.id, level, xp);
    return { petId: equipped.id, level, xp, gained, messages };
  }
}

module.exports = PetManager;
