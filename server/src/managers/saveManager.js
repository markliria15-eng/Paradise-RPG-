const characterRepo = require("../repositories/characterRepository");

class SaveManager {
  async savePlayerState(playerState) {
    await characterRepo.upsertState({
      id: playerState.characterId,
      level: playerState.level,
      xp: playerState.xp,
      hp: playerState.hp,
      mana: playerState.mana,
      gold: playerState.gold,
      map: playerState.map,
      pos: playerState.pos
    });
  }

  async saveAll(players) {
    for (const player of players) {
      await this.savePlayerState(player);
    }
  }
}

module.exports = SaveManager;

