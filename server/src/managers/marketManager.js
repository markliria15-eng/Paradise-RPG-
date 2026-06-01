const mmoRepo = require("../repositories/mmoRepository");

class MarketManager {
  constructor() {
    this.taxRate = 0.05;
  }

  async list(filters = {}) {
    return mmoRepo.listMarket(filters);
  }

  async createListing({ sellerCharacterId, itemId, quantity, price, rarity, category }) {
    if (quantity <= 0 || price <= 0) throw new Error("Quantidade/preco invalidos.");
    const removed = await mmoRepo.removeInventoryItem(sellerCharacterId, itemId, quantity);
    if (!removed) throw new Error("Item insuficiente para listar no mercado.");
    return mmoRepo.createListing({
      sellerCharacterId,
      itemId,
      quantity,
      price,
      rarity: rarity || "common",
      category: category || "misc"
    });
  }

  async cancelListing(listingId, requesterCharacterId) {
    const listing = await mmoRepo.findListingById(listingId);
    if (!listing) throw new Error("Anuncio nao encontrado.");
    if (Number(listing.seller_character_id) !== Number(requesterCharacterId)) {
      throw new Error("Nao e possivel cancelar anuncio de outro jogador.");
    }
    if (listing.status !== "active") throw new Error("Anuncio nao esta ativo.");
    await mmoRepo.closeListing(listingId, "cancelled");
    await mmoRepo.addInventoryItem(requesterCharacterId, listing.item_id, listing.quantity);
    return true;
  }

  async buy(listingId, buyerCharacterId) {
    const listing = await mmoRepo.findListingById(listingId);
    if (!listing) throw new Error("Anuncio inexistente.");
    if (listing.status !== "active") throw new Error("Anuncio indisponivel.");
    if (Number(listing.seller_character_id) === Number(buyerCharacterId)) {
      throw new Error("Nao pode comprar o proprio anuncio.");
    }

    const paid = await mmoRepo.removeGold(buyerCharacterId, Number(listing.price));
    if (!paid) throw new Error("Ouro insuficiente.");

    await mmoRepo.closeListing(listing.id, "sold");
    await mmoRepo.addInventoryItem(buyerCharacterId, listing.item_id, Number(listing.quantity));

    const tax = Math.floor(Number(listing.price) * this.taxRate);
    const net = Number(listing.price) - tax;
    await mmoRepo.addGold(Number(listing.seller_character_id), net);

    return { listingId: listing.id, tax, paid: Number(listing.price), sellerReceived: net };
  }
}

module.exports = MarketManager;

