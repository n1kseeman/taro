class CartLineAddon {
  final String menuItemId;
  final int qty;

  const CartLineAddon({required this.menuItemId, required this.qty});

  Map<String, dynamic> toJson() => {"menuItemId": menuItemId, "qty": qty};

  static CartLineAddon fromJson(Map<String, dynamic> j) =>
      CartLineAddon(menuItemId: j["menuItemId"], qty: j["qty"]);
}

class CartLine {
  final String menuItemId;
  final String? sizeId; // выбранный размер (если есть)
  final List<String> addonIds; // выбранные добавки
  final List<CartLineAddon> attachedAddons;
  int qty;

  CartLine({
    required this.menuItemId,
    required this.qty,
    this.sizeId,
    this.addonIds = const [],
    this.attachedAddons = const [],
  });

  String get key {
    final attachedKey = attachedAddons
        .map((addon) => "${addon.menuItemId}:${addon.qty}")
        .join(",");
    return "$menuItemId|${sizeId ?? "no"}|${addonIds.join(",")}|$attachedKey";
  }

  Map<String, dynamic> toJson() => {
    "menuItemId": menuItemId,
    "sizeId": sizeId,
    "addonIds": addonIds,
    "attachedAddons": attachedAddons.map((e) => e.toJson()).toList(),
    "qty": qty,
  };

  static CartLine fromJson(Map<String, dynamic> j) => CartLine(
    menuItemId: j["menuItemId"],
    sizeId: j["sizeId"],
    addonIds: (j["addonIds"] as List).map((e) => e.toString()).toList(),
    attachedAddons: (j["attachedAddons"] as List? ?? [])
        .map((e) => CartLineAddon.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    qty: j["qty"],
  );
}

class Cart {
  final String cafeId;
  final Map<String, CartLine> linesByKey;

  Cart({required this.cafeId, Map<String, CartLine>? linesByKey})
    : linesByKey = linesByKey ?? {};

  bool get isEmpty => linesByKey.isEmpty;

  Map<String, dynamic> toJson() => {
    "cafeId": cafeId,
    "lines": linesByKey.values.map((e) => e.toJson()).toList(),
  };

  static Cart fromJson(Map<String, dynamic> j) {
    final lines = (j["lines"] as List)
        .map((e) => CartLine.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final map = {for (final l in lines) l.key: l};
    return Cart(cafeId: j["cafeId"], linesByKey: map);
  }
}
