enum MenuCategory {
  constructor,
  milkBase,
  fruitCream,
  bubbleCoffee,
  matcha,
  fruitTea,
  coffee,
  addons,
}

const legacyAlternativeMilkAddonId = "alt_milk";

String menuCategoryTitle(MenuCategory category) {
  switch (category) {
    case MenuCategory.constructor:
      return "Конструктор";
    case MenuCategory.milkBase:
      return "Milk Base";
    case MenuCategory.fruitCream:
      return "Fruit&Cream";
    case MenuCategory.bubbleCoffee:
      return "Bubble coffee";
    case MenuCategory.matcha:
      return "Matcha";
    case MenuCategory.fruitTea:
      return "Fruit&Tea";
    case MenuCategory.coffee:
      return "Кофе";
    case MenuCategory.addons:
      return "Добавки";
  }
}

class Nutrition {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const Nutrition({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  Map<String, dynamic> toJson() => {
    "kcal": kcal,
    "protein": protein,
    "fat": fat,
    "carbs": carbs,
  };

  static Nutrition fromJson(Map<String, dynamic> j) => Nutrition(
    kcal: (j["kcal"] ?? 0).toDouble(),
    protein: (j["protein"] ?? 0).toDouble(),
    fat: (j["fat"] ?? 0).toDouble(),
    carbs: (j["carbs"] ?? 0).toDouble(),
  );
}

class MenuSize {
  final String id;
  final String label;
  final int? volumeMl;
  final double priceDelta;

  const MenuSize({
    required this.id,
    required this.label,
    this.volumeMl,
    required this.priceDelta,
  });

  String get displayLabel {
    final trimmedLabel = label.trim();
    final volume = volumeMl;
    if (volume != null && volume > 0) {
      if (trimmedLabel.isEmpty) return "$volume мл";
      return "$trimmedLabel • $volume мл";
    }
    return trimmedLabel;
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "label": label,
    "volumeMl": volumeMl,
    "priceDelta": priceDelta,
  };

  static MenuSize fromJson(Map<String, dynamic> j) => MenuSize(
    id: j["id"],
    label: j["label"],
    volumeMl: j["volumeMl"] == null
        ? null
        : int.tryParse(j["volumeMl"].toString()),
    priceDelta: (j["priceDelta"] ?? 0).toDouble(),
  );
}

class MenuAddon {
  final String id;
  final String name;
  final double price;
  final String imageUrl;

  const MenuAddon({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl = "",
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "price": price,
    "imageUrl": imageUrl,
  };

  static MenuAddon fromJson(Map<String, dynamic> j) => MenuAddon(
    id: j["id"],
    name: j["name"],
    price: (j["price"] ?? 0).toDouble(),
    imageUrl: (j["imageUrl"] ?? "") as String,
  );
}

class MenuItem {
  final String id;
  final MenuCategory category;
  final String name;
  final double basePrice;
  final String description;
  final Nutrition nutrition;
  final List<MenuSize> sizes;
  final List<MenuAddon> addons;
  final bool showNutrition;
  final bool isHidden;
  final bool isTop;
  final String imageUrl;

  const MenuItem({
    required this.id,
    required this.category,
    required this.name,
    required this.basePrice,
    required this.description,
    required this.nutrition,
    this.sizes = const [],
    this.addons = const [],
    this.showNutrition = true,
    this.imageUrl = "",
    this.isHidden = false,
    this.isTop = false,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "category": category.name,
    "name": name,
    "basePrice": basePrice,
    "description": description,
    "nutrition": nutrition.toJson(),
    "sizes": sizes.map((e) => e.toJson()).toList(),
    "addons": addons.map((e) => e.toJson()).toList(),
    "showNutrition": showNutrition,
    "imageUrl": imageUrl,
    "isHidden": isHidden,
    "isTop": isTop,
  };

  static MenuItem fromJson(Map<String, dynamic> j) => MenuItem(
    id: j["id"],
    category: switch (j["category"]) {
      "lemonades" => MenuCategory.matcha,
      final String name => MenuCategory.values.firstWhere(
        (c) => c.name == name,
      ),
      _ => MenuCategory.milkBase,
    },
    name: j["name"],
    basePrice: (j["basePrice"] ?? 0).toDouble(),
    description: (j["description"] ?? "") as String,
    nutrition: Nutrition.fromJson(
      Map<String, dynamic>.from(j["nutrition"] ?? {}),
    ),
    sizes: (j["sizes"] as List? ?? [])
        .map((e) => MenuSize.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    addons: (j["addons"] as List? ?? [])
        .map((e) => MenuAddon.fromJson(Map<String, dynamic>.from(e)))
        .where((addon) => addon.id != legacyAlternativeMilkAddonId)
        .toList(),
    showNutrition: (j["showNutrition"] ?? true) != false,
    imageUrl: (j["imageUrl"] ?? "") as String,
    isHidden: (j["isHidden"] ?? false) == true,
    isTop: (j["isTop"] ?? false) == true,
  );
}
