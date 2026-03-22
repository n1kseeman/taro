import 'dart:convert';
import 'package:hive/hive.dart';

import '../models/cart.dart';
import '../models/menu.dart';
import '../models/order.dart';
import '../models/promo_code.dart';
import '../models/user.dart';

class HiveService {
  static const _boxName = "tm_box";

  static const _kSelectedCafeId = "selectedCafeId";
  static const _kRememberCafe = "rememberCafe";

  static const _kFavorites = "favorites"; // legacy/совместимость
  static const _kFavoritesByUser = "favorites_by_user";

  static const _kCart = "cart";
  static const _kOrders = "orders";
  static const _kPromoCodes = "promoCodes";
  static const _kUsers = "users";
  static const _kSessionUserId = "sessionUserId";
  static const _kThemeMode = "themeMode";

  static const _kDefaultMenu = "defaultMenu";
  static const _kCafeMenuOverrides = "cafeMenuOverrides";

  static const _kGlobalAddons = "globalAddons";

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    Future<void> putIfAbsent(String key, Object value) async {
      if (!_box.containsKey(key)) {
        await _box.put(key, value);
      }
    }

    await putIfAbsent(_kOrders, "[]");
    await putIfAbsent(_kPromoCodes, "[]");
    await putIfAbsent(_kFavoritesByUser, "{}");
    await putIfAbsent(_kFavorites, "[]");
    await putIfAbsent(_kUsers, "[]");
    await putIfAbsent(_kCafeMenuOverrides, "{}");
    await putIfAbsent(_kRememberCafe, true);
    await putIfAbsent(_kGlobalAddons, "[]");
    await putIfAbsent(_kThemeMode, "system");
  }

  // --- Remember cafe ---
  bool get rememberCafe => (_box.get(_kRememberCafe) as bool?) ?? true;

  Future<void> setRememberCafe(bool v) async {
    await _box.put(_kRememberCafe, v);
  }

  // --- Selected cafe ---
  String? get selectedCafeId => _box.get(_kSelectedCafeId) as String?;

  Future<void> setSelectedCafeId(String? id) async {
    if (id == null) {
      await _box.delete(_kSelectedCafeId);
    } else {
      await _box.put(_kSelectedCafeId, id);
    }
  }

  // --- Favorites by user ---
  Map<String, List<String>> get favoritesByUser {
    final raw = (_box.get(_kFavoritesByUser) ?? "{}") as String;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );
    } catch (_) {
      _box.put(_kFavoritesByUser, "{}");
      return {};
    }
  }

  Future<void> saveFavoritesForUser(String userId, List<String> ids) async {
    final map = favoritesByUser;
    map[userId] = ids;
    await _box.put(_kFavoritesByUser, jsonEncode(map));
  }

  Future<void> deleteFavoritesForUser(String userId) async {
    final map = favoritesByUser;
    map.remove(userId);
    await _box.put(_kFavoritesByUser, jsonEncode(map));
  }

  // --- Legacy favorites ---
  List<String> get favorites {
    final raw = (_box.get(_kFavorites) ?? "[]") as String;
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      _box.put(_kFavorites, "[]");
      return [];
    }
  }

  Future<void> saveFavorites(List<String> ids) async {
    await _box.put(_kFavorites, jsonEncode(ids));
  }

  // --- Global addons ---
  List<MenuAddon> get globalAddons {
    final raw = (_box.get(_kGlobalAddons) ?? "[]") as String;
    try {
      return (jsonDecode(raw) as List)
          .map((e) => MenuAddon.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      _box.put(_kGlobalAddons, "[]");
      return [];
    }
  }

  Future<void> saveGlobalAddons(List<MenuAddon> addons) async {
    await _box.put(
      _kGlobalAddons,
      jsonEncode(addons.map((a) => a.toJson()).toList()),
    );
  }

  // --- Cart ---
  Cart? get cart {
    final raw = _box.get(_kCart) as String?;
    if (raw == null) return null;
    return Cart.fromJson(jsonDecode(raw));
  }

  Future<void> saveCart(Cart? cart) async {
    if (cart == null) {
      await _box.delete(_kCart);
      return;
    }
    await _box.put(_kCart, jsonEncode(cart.toJson()));
  }

  // --- Orders ---
  List<Order> get orders {
    final raw = (_box.get(_kOrders) ?? "[]") as String;
    return (jsonDecode(raw) as List)
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveOrders(List<Order> orders) async {
    await _box.put(
      _kOrders,
      jsonEncode(orders.map((o) => o.toJson()).toList()),
    );
  }

  List<PromoCode> get promoCodes {
    final raw = (_box.get(_kPromoCodes) ?? "[]") as String;
    return (jsonDecode(raw) as List)
        .map((e) => PromoCode.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> savePromoCodes(List<PromoCode> promoCodes) async {
    await _box.put(
      _kPromoCodes,
      jsonEncode(promoCodes.map((promo) => promo.toJson()).toList()),
    );
  }

  // --- Users / session ---
  List<AppUser> get users {
    final raw = (_box.get(_kUsers) ?? "[]") as String;
    return (jsonDecode(raw) as List)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveUsers(List<AppUser> users) async {
    await _box.put(_kUsers, jsonEncode(users.map((u) => u.toJson()).toList()));
  }

  String? get sessionUserId => _box.get(_kSessionUserId) as String?;

  Future<void> setSessionUserId(String? id) async {
    if (id == null) {
      await _box.delete(_kSessionUserId);
    } else {
      await _box.put(_kSessionUserId, id);
    }
  }

  String get themeModeName => (_box.get(_kThemeMode) as String?) ?? "system";

  Future<void> setThemeModeName(String value) async {
    await _box.put(_kThemeMode, value);
  }

  // --- Menu ---
  List<MenuItem> get defaultMenu {
    final raw = _box.get(_kDefaultMenu) as String?;
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveDefaultMenu(List<MenuItem> items) async {
    await _box.put(
      _kDefaultMenu,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Map<String, List<MenuItem>> get cafeMenuOverrides {
    final raw = (_box.get(_kCafeMenuOverrides) ?? "{}") as String;
    final map = Map<String, dynamic>.from(jsonDecode(raw));

    return map.map((cafeId, menuJsonList) {
      final list = (menuJsonList as List)
          .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return MapEntry(cafeId, list);
    });
  }

  Future<void> saveCafeMenuOverride(String cafeId, List<MenuItem> items) async {
    final current = cafeMenuOverrides;
    current[cafeId] = items;

    final jsonMap = current.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    );

    await _box.put(_kCafeMenuOverrides, jsonEncode(jsonMap));
  }
}
