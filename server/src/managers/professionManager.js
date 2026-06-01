const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");

const PROFESSION_KEYS = ["mining", "woodcutting", "herbalism", "blacksmithing", "alchemy", "cooking"];

class ProfessionManager {
  constructor() {
    this.base = loadProjectJson("data/mmo_professions.json");
  }

  xpRequired(level) {
    return 100 + level * 50;
  }

  async snapshot(characterId) {
    const row = await mmoRepo.getProfessions(characterId);
    const result = {};
    for (const key of PROFESSION_KEYS) {
      const level = Number(row?.[`${key}_level`] || this.base[key].level || 1);
      const xp = Number(row?.[`${key}_xp`] || this.base[key].xp || 0);
      result[key] = {
        name: this.base[key].name,
        level,
        xp,
        xp_required: this.xpRequired(level)
      };
    }
    return result;
  }

  async addXp(characterId, key, delta) {
    if (!PROFESSION_KEYS.includes(key)) {
      throw new Error("Profissao invalida.");
    }
    const profs = await this.snapshot(characterId);
    const current = profs[key];
    current.xp += Math.max(0, Number(delta) || 0);
    const messages = [];
    while (current.xp >= current.xp_required) {
      current.xp -= current.xp_required;
      current.level += 1;
      current.xp_required = this.xpRequired(current.level);
      messages.push(`Sua profissao ${current.name} subiu para o nivel ${current.level}!`);
    }
    await mmoRepo.updateProfession(characterId, key, current.level, current.xp);
    return { profession: current, messages };
  }
}

module.exports = ProfessionManager;

