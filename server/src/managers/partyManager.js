class PartyManager {
  constructor() {
    this.parties = new Map();
    this.invites = new Map();
    this.nextId = 1;
  }

  invite(leaderId, targetId) {
    this.invites.set(targetId, { leaderId, targetId, at: Date.now() });
  }

  accept(targetId) {
    const invite = this.invites.get(targetId);
    if (!invite) return null;
    this.invites.delete(targetId);
    let party = [...this.parties.values()].find((p) => p.leaderId === invite.leaderId);
    if (!party) {
      party = { id: this.nextId++, leaderId: invite.leaderId, members: [invite.leaderId] };
      this.parties.set(party.id, party);
    }
    if (!party.members.includes(targetId)) {
      party.members.push(targetId);
    }
    return party;
  }

  leave(characterId) {
    for (const [partyId, party] of this.parties.entries()) {
      if (!party.members.includes(characterId)) continue;
      party.members = party.members.filter((id) => id !== characterId);
      if (party.leaderId === characterId && party.members.length > 0) {
        party.leaderId = party.members[0];
      }
      if (party.members.length === 0) {
        this.parties.delete(partyId);
      }
      return party;
    }
    return null;
  }
}

module.exports = PartyManager;

