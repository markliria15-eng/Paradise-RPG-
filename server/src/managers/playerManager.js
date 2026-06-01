class PlayerManager {
  constructor() {
    this.byCharacterId = new Map();
    this.bySocket = new Map();
    this.pendingMoves = new Map();
  }

  addSession(socket, payload) {
    const session = {
      socket,
      accountId: payload.accountId,
      characterId: payload.character.id,
      name: payload.character.name,
      className: payload.character.class,
      level: payload.character.level,
      xp: payload.character.xp,
      hp: payload.character.hp,
      mana: payload.character.mana,
      gold: payload.character.gold,
      map: payload.character.map,
      pos: { x: payload.character.pos_x, y: payload.character.pos_y },
      guildId: null,
      partyId: null,
      connectedAt: Date.now(),
      lastPacketAt: Date.now(),
      lastSaveAt: Date.now()
    };
    this.byCharacterId.set(session.characterId, session);
    this.bySocket.set(socket, session.characterId);
    return session;
  }

  removeSession(socket) {
    const characterId = this.bySocket.get(socket);
    if (!characterId) return null;
    this.bySocket.delete(socket);
    this.pendingMoves.delete(characterId);
    const session = this.byCharacterId.get(characterId) || null;
    this.byCharacterId.delete(characterId);
    return session;
  }

  getBySocket(socket) {
    const characterId = this.bySocket.get(socket);
    if (!characterId) return null;
    return this.byCharacterId.get(characterId) || null;
  }

  get(characterId) {
    return this.byCharacterId.get(characterId) || null;
  }

  all() {
    return [...this.byCharacterId.values()];
  }

  queueMove(characterId, mapId, pos) {
    this.pendingMoves.set(characterId, { map: mapId, pos, at: Date.now() });
  }

  drainPendingMoves() {
    const entries = [...this.pendingMoves.entries()];
    this.pendingMoves.clear();
    return entries;
  }

  playersInMap(mapId) {
    return this.all().filter((p) => p.map === mapId);
  }
}

module.exports = PlayerManager;

