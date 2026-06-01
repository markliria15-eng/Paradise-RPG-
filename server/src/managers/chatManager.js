class ChatManager {
  constructor(config) {
    this.config = config;
    this.recentMessages = new Map();
  }

  canTalk(characterId) {
    const now = Date.now();
    const windowMs = this.config.chatFloodWindowMs;
    const max = this.config.chatFloodMaxMessages;
    const list = this.recentMessages.get(characterId) || [];
    const kept = list.filter((at) => now - at < windowMs);
    if (kept.length >= max) {
      this.recentMessages.set(characterId, kept);
      return false;
    }
    kept.push(now);
    this.recentMessages.set(characterId, kept);
    return true;
  }

  buildMessage(channel, fromName, text) {
    return {
      type: "chat_message",
      channel,
      from: fromName,
      text: String(text).slice(0, 280),
      at: new Date().toISOString()
    };
  }
}

module.exports = ChatManager;

