const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");

class CraftingManager {
  constructor({ professionManager }) {
    this.professionManager = professionManager;
    this.recipes = loadProjectJson("data/mmo_crafting_recipes.json");
  }

  listRecipes() {
    return this.recipes;
  }

  recipeByCode(code) {
    return this.recipes.find((r) => r.code === code) || null;
  }

  async craft(characterId, code) {
    const recipe = this.recipeByCode(code);
    if (!recipe) throw new Error("Receita nao encontrada.");
    const professions = await this.professionManager.snapshot(characterId);
    const prof = professions[recipe.profession];
    if (!prof) throw new Error("Profissao invalida para receita.");
    if (prof.level < recipe.profession_level_required) {
      throw new Error("Nivel de profissao insuficiente.");
    }

    for (const material of recipe.materials) {
      const row = await mmoRepo.getCharacterInventoryItem(characterId, material.item_id);
      if (!row || Number(row.amount) < Number(material.amount)) {
        throw new Error(`Material insuficiente: ${material.item_id}`);
      }
    }

    for (const material of recipe.materials) {
      const ok = await mmoRepo.removeInventoryItem(characterId, material.item_id, material.amount);
      if (!ok) throw new Error(`Falha ao consumir material: ${material.item_id}`);
    }

    if (recipe.gold_cost > 0) {
      const paid = await mmoRepo.removeGold(characterId, recipe.gold_cost);
      if (!paid) {
        throw new Error("Ouro insuficiente para craft.");
      }
    }

    const roll = Math.random() * 100;
    const success = roll <= Number(recipe.success_chance || 100);
    if (success) {
      await mmoRepo.addInventoryItem(characterId, recipe.result_item_id, recipe.result_amount);
    }

    const profResult = await this.professionManager.addXp(characterId, recipe.profession, success ? 18 : 6);
    return {
      success,
      recipe,
      profession: profResult.profession,
      messages: profResult.messages
    };
  }
}

module.exports = CraftingManager;
