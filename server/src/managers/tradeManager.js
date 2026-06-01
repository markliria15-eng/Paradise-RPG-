const tradeRepo = require("../repositories/tradeRepository");

class TradeManager {
  constructor() {
    this.requests = new Map();
    this.activeTrades = new Map();
  }

  request(fromPlayer, toPlayer) {
    const key = `${fromPlayer.characterId}:${toPlayer.characterId}`;
    this.requests.set(key, {
      from: fromPlayer.characterId,
      to: toPlayer.characterId,
      at: Date.now()
    });
  }

  hasRequest(fromId, toId) {
    return this.requests.has(`${fromId}:${toId}`);
  }

  openTrade(playerA, playerB) {
    const id = `${Math.min(playerA.characterId, playerB.characterId)}:${Math.max(playerA.characterId, playerB.characterId)}`;
    const trade = {
      id,
      a: playerA.characterId,
      b: playerB.characterId,
      offerA: [],
      offerB: [],
      confirmA: false,
      confirmB: false,
      startedAt: Date.now()
    };
    this.activeTrades.set(id, trade);
    return trade;
  }

  getTradeByCharacter(characterId) {
    for (const trade of this.activeTrades.values()) {
      if (trade.a === characterId || trade.b === characterId) {
        return trade;
      }
    }
    return null;
  }

  updateOffer(characterId, items) {
    const trade = this.getTradeByCharacter(characterId);
    if (!trade) return null;
    if (trade.a === characterId) {
      trade.offerA = items;
      trade.confirmA = false;
      trade.confirmB = false;
    } else {
      trade.offerB = items;
      trade.confirmA = false;
      trade.confirmB = false;
    }
    return trade;
  }

  confirm(characterId) {
    const trade = this.getTradeByCharacter(characterId);
    if (!trade) return { done: false, trade: null };
    if (trade.a === characterId) trade.confirmA = true;
    if (trade.b === characterId) trade.confirmB = true;
    return { done: trade.confirmA && trade.confirmB, trade };
  }

  async finalize(trade) {
    this.activeTrades.delete(trade.id);
    await tradeRepo.appendTradeLog({
      actorA: trade.a,
      actorB: trade.b,
      payload: {
        offerA: trade.offerA,
        offerB: trade.offerB,
        startedAt: trade.startedAt,
        finishedAt: Date.now()
      }
    });
  }

  cancelForCharacter(characterId) {
    const trade = this.getTradeByCharacter(characterId);
    if (!trade) return null;
    this.activeTrades.delete(trade.id);
    return trade;
  }
}

module.exports = TradeManager;

