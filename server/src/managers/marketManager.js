const mmoRepo = require("../repositories/mmoRepository");
const itemValue = require("../utils/itemValue");

// Mercado entre jogadores (estilo Albion): cada jogador anuncia pelo preco que quiser; o jogo recomenda
// o preco (mediana das ultimas vendas por unidade, ou o valor base de data/mercado.json) e o cliente
// avisa quando o anuncio fica abaixo do valor de mercado. O dinheiro da venda vai para market_payouts
// (o vendedor coleta quando quiser, mesmo que estivesse offline na hora da venda).
class MarketManager {
  constructor() {
    this.taxRate = Number(itemValue.marketRules().taxa_venda ?? 0.05);
  }

  async list(filters = {}, requesterCharacterId = null) {
    const listings = await mmoRepo.listMarket(filters);
    const prices = {};
    for (const listing of listings) {
      listing.mine = requesterCharacterId != null && Number(listing.seller_character_id) === Number(requesterCharacterId);
      if (!(listing.item_id in prices)) prices[listing.item_id] = await this.suggestedPrice(listing.item_id);
      listing.unit_price = Math.round(Number(listing.price) / Math.max(1, Number(listing.quantity)));
    }
    return { listings, prices };
  }

  // preco recomendado por unidade
  async suggestedPrice(itemId) {
    const rules = itemValue.marketRules();
    const sales = await mmoRepo.recentUnitPrices(itemId, Number(rules.recomendado_vendas || 20));
    const base = itemValue.baseValue(itemId);
    if (sales.length >= Number(rules.recomendado_min_vendas || 3)) {
      return { itemId, suggested: itemValue.median(sales), base, sales: sales.length, source: "mercado" };
    }
    return { itemId, suggested: base, base, sales: sales.length, source: "valor_base" };
  }

  async createListing({ sellerCharacterId, itemId, quantity, price, rarity, category }) {
    quantity = Math.floor(Number(quantity));
    price = Math.floor(Number(price));
    if (!itemValue.itemExists(itemId)) throw new Error("Item desconhecido.");
    if (!(quantity > 0) || !(price > 0)) throw new Error("Quantidade/preco invalidos.");
    // Inventario online ainda nao e a fonte da verdade (o cliente guarda o inventario local):
    // tira do inventario do servidor quando o item estiver la; senao confia no cliente.
    // TODO(anti-cheat): exigir o item no inventario do servidor quando ele estiver sincronizado.
    await mmoRepo.removeInventoryItem(sellerCharacterId, itemId, quantity).catch(() => false);
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
    return { listingId: Number(listing.id), itemId: listing.item_id, quantity: Number(listing.quantity) };
  }

  async buy(listingId, buyerCharacterId) {
    const listing = await mmoRepo.findListingById(listingId);
    if (!listing) throw new Error("Anuncio inexistente.");
    if (listing.status !== "active") throw new Error("Anuncio indisponivel.");
    if (Number(listing.seller_character_id) === Number(buyerCharacterId)) {
      throw new Error("Nao pode comprar o proprio anuncio.");
    }
    const closed = await mmoRepo.closeListing(listing.id, "sold", "active");
    if (!closed) throw new Error("Anuncio ja foi vendido.");
    const paid = await mmoRepo.removeGold(buyerCharacterId, Number(listing.price));
    if (!paid) {
      await mmoRepo.reopenListing(listing.id);
      throw new Error("Ouro insuficiente.");
    }
    const tax = Math.floor(Number(listing.price) * this.taxRate);
    const net = Number(listing.price) - tax;
    await mmoRepo.createPayout(Number(listing.seller_character_id), Number(listing.id), net);
    return {
      listingId: Number(listing.id),
      itemId: listing.item_id,
      quantity: Number(listing.quantity),
      tax,
      paid: Number(listing.price),
      sellerReceives: net
    };
  }

  async pendingPayouts(characterId) {
    return mmoRepo.sumPendingPayouts(characterId);
  }

  async collectPayouts(characterId) {
    const amount = await mmoRepo.collectPayouts(characterId);
    return { amount };
  }
}

module.exports = MarketManager;
