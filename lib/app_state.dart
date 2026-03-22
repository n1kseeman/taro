import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'models/cafe.dart';
import 'models/menu.dart';
import 'models/cart.dart';
import 'models/order.dart';
import 'models/promo_code.dart';
import 'models/user.dart';
import 'services/cloud_sync_service.dart';
import 'services/firebase_bootstrap_service.dart';
import 'services/menu_seed_service.dart';
import 'storage/hive_service.dart';

class AppState extends ChangeNotifier {
  final HiveService storage;
  final CloudSyncService? _cloudSync;
  final FirebaseBootstrapService? _firebaseBootstrapService;
  final _uuid = const Uuid();

  AppState(
    this.storage, {
    CloudSyncService? cloudSync,
    FirebaseBootstrapService? firebaseBootstrapService,
  }) : _cloudSync = cloudSync,
       _firebaseBootstrapService = firebaseBootstrapService;

  static String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  // ✅ Одна кофейня: Taro Tea
  final Cafe cafe = Cafe(
    id: "tapo",
    name: "Taro Tea",
    address: "Минск",
    adminLogin: "admin",
    adminPasswordHash: _hash("admin"),
  );

  late final List<Cafe> cafes = [cafe];
  late final Cafe _selectedCafe = cafe;
  Cafe get selectedCafe => _selectedCafe;

  Cart? _cart;
  Cart? get cart => _cart;

  List<Order> _orders = [];
  List<Order> get orders => _orders;

  List<PromoCode> _promoCodes = [];
  List<PromoCode> get promoCodes {
    final list = List<PromoCode>.from(_promoCodes);
    list.sort((a, b) {
      final aAvailable = a.isActive && !a.isExhausted;
      final bAvailable = b.isActive && !b.isExhausted;
      if (aAvailable != bAvailable) return aAvailable ? -1 : 1;
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  String? _appliedPromoId;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthed => _currentUser != null;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  List<MenuItem>? _allMenuItemsCache;
  Object? _allMenuItemsCacheSource;
  bool? _allMenuItemsCacheIsAdmin;

  List<MenuItem>? _menuCache;
  Object? _menuCacheBaseIdentity;

  List<MenuItem>? _favoriteMenuItemsCache;
  Object? _favoriteMenuCacheBaseIdentity;
  int? _favoriteMenuCacheVersion;
  int _favoriteMenuVersion = 0;

  // ---- Favorites (привязано к аккаунту) ----
  Set<String> _favoriteIds = {};
  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String menuItemId) => _favoriteIds.contains(menuItemId);

  List<MenuItem> get favoriteMenuItems {
    final baseMenu = menu;
    if (_favoriteMenuItemsCache != null &&
        identical(_favoriteMenuCacheBaseIdentity, baseMenu) &&
        _favoriteMenuCacheVersion == _favoriteMenuVersion) {
      return _favoriteMenuItemsCache!;
    }

    final set = _favoriteIds;
    final list = baseMenu.where((m) => set.contains(m.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _favoriteMenuCacheBaseIdentity = baseMenu;
    _favoriteMenuCacheVersion = _favoriteMenuVersion;
    _favoriteMenuItemsCache = List<MenuItem>.unmodifiable(list);
    return _favoriteMenuItemsCache!;
  }

  void _invalidateMenuCaches() {
    _allMenuItemsCache = null;
    _allMenuItemsCacheSource = null;
    _allMenuItemsCacheIsAdmin = null;
    _menuCache = null;
    _menuCacheBaseIdentity = null;
    _favoriteMenuItemsCache = null;
    _favoriteMenuCacheBaseIdentity = null;
    _favoriteMenuCacheVersion = null;
  }

  void _setFavoriteIds(Set<String> ids) {
    _favoriteIds = ids;
    _favoriteMenuVersion += 1;
    _favoriteMenuItemsCache = null;
    _favoriteMenuCacheBaseIdentity = null;
    _favoriteMenuCacheVersion = null;
  }

  MenuSeedData _currentMenuSeedData() {
    final override = storage.cafeMenuOverrides[cafe.id];
    final menu = override != null && override.isNotEmpty
        ? override
        : storage.defaultMenu;
    return MenuSeedData(
      menu: List<MenuItem>.from(menu),
      globalAddons: List<MenuAddon>.from(storage.globalAddons),
      promoCodes: List<PromoCode>.from(_promoCodes),
    );
  }

  Future<void> _applyRemoteMenuSeed(MenuSeedData data) async {
    await storage.saveDefaultMenu(data.menu);
    await storage.saveGlobalAddons(data.globalAddons);
    await storage.saveCafeMenuOverride(cafe.id, data.menu);
    await storage.savePromoCodes(data.promoCodes);
    _promoCodes = List<PromoCode>.from(data.promoCodes);
    _revalidateAppliedPromo();
    _invalidateMenuCaches();
    notifyListeners();
  }

  Future<void> _applyRemoteOrders(List<Order> orders) async {
    _orders = List<Order>.from(orders);
    await storage.saveOrders(_orders);
    notifyListeners();
  }

  Future<void> _startCloudSync() async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) return;

    await cloudSync.start(
      cafeId: cafe.id,
      initialSeed: _currentMenuSeedData(),
      includeAllOrders: _isAdmin,
      currentUserId: _isAdmin ? null : _currentUser?.id,
      onMenuChanged: _applyRemoteMenuSeed,
      onOrdersChanged: _applyRemoteOrders,
    );
  }

  Future<void> _restartCloudSync() async {
    await _startCloudSync();
  }

  Future<void> _syncMenuSeedToCloud() async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) return;
    await cloudSync.saveMenuSeed(cafeId: cafe.id, data: _currentMenuSeedData());
  }

  CloudSyncService _requireCloudSync() {
    final cloudSync = _cloudSync;
    if (cloudSync == null) {
      throw StateError('CLOUD_SYNC_UNAVAILABLE');
    }
    return cloudSync;
  }

  Future<List<String>> _notificationTokensForCheckout() async {
    if (_currentUser?.notificationsEnabled != true) return const [];
    final token = await _firebaseBootstrapService?.enableMessaging(
      requestPermission: false,
    );
    if (token == null || token.trim().isEmpty) return const [];
    return [token];
  }

  void _loadFavoritesForCurrentUser() {
    if (_currentUser == null) {
      _setFavoriteIds(<String>{});
      return;
    }
    final map = storage.favoritesByUser;
    _setFavoriteIds((map[_currentUser!.id] ?? []).toSet());
  }

  Future<void> toggleFavorite(String menuItemId) async {
    if (_currentUser == null) throw Exception("AUTH_REQUIRED");

    final next = Set<String>.from(_favoriteIds);
    if (next.contains(menuItemId)) {
      next.remove(menuItemId);
    } else {
      next.add(menuItemId);
    }

    _setFavoriteIds(next);
    await storage.saveFavoritesForUser(_currentUser!.id, _favoriteIds.toList());
    notifyListeners();
  }

  // ---- Init ----
  Future<void> init() async {
    await _firebaseBootstrapService?.ensureInitialized();
    _orders = storage.orders;
    _promoCodes = storage.promoCodes;
    _themeMode = _themeModeFromName(storage.themeModeName);

    final userId = storage.sessionUserId;
    if (userId != null) {
      final u = storage.users.where((x) => x.id == userId).toList();
      if (u.isNotEmpty) _currentUser = u.first;
    }

    final bundledSeed = await MenuSeedService.loadBundledSeed();
    if (bundledSeed != null) {
      await storage.saveDefaultMenu(bundledSeed.menu);
      await storage.saveGlobalAddons(bundledSeed.globalAddons);
      await storage.saveCafeMenuOverride(cafe.id, bundledSeed.menu);
      await storage.savePromoCodes(bundledSeed.promoCodes);
      _promoCodes = bundledSeed.promoCodes;
    } else if (storage.defaultMenu.isEmpty) {
      await storage.saveDefaultMenu(_demoMenu());
    }
    await _removeLegacyAlternativeMilkData();
    await _restoreDemoImagesIfMissing();

    _cart = storage.cart;
    if (_cart == null || _cart!.cafeId != cafe.id) {
      _cart = Cart(cafeId: cafe.id);
      await storage.saveCart(_cart);
    }

    await storage.setSelectedCafeId(null);

    _loadFavoritesForCurrentUser();
    _revalidateAppliedPromo();
    _invalidateMenuCaches();

    if (_currentUser?.notificationsEnabled == true) {
      await _firebaseBootstrapService?.enableMessaging(
        requestPermission: false,
      );
    }

    await _startCloudSync();
    notifyListeners();
  }

  ThemeMode _themeModeFromName(String value) {
    switch (value) {
      case "light":
        return ThemeMode.light;
      case "dark":
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeName(ThemeMode value) {
    switch (value) {
      case ThemeMode.light:
        return "light";
      case ThemeMode.dark:
        return "dark";
      case ThemeMode.system:
        return "system";
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await storage.setThemeModeName(_themeModeName(value));
    notifyListeners();
  }

  Future<void> _restoreDemoImagesIfMissing() async {
    final demoById = {
      for (final m in _demoMenu())
        if (m.imageUrl.trim().isNotEmpty) m.id: m.imageUrl,
    };

    Future<List<MenuItem>> patched(List<MenuItem> source) async {
      return source.map((item) {
        final demoImage = demoById[item.id];
        if (demoImage == null || item.imageUrl.trim().isNotEmpty) return item;
        return MenuItem(
          id: item.id,
          category: item.category,
          name: item.name,
          basePrice: item.basePrice,
          description: item.description,
          nutrition: item.nutrition,
          sizes: item.sizes,
          addons: item.addons,
          showNutrition: item.showNutrition,
          imageUrl: demoImage,
          isHidden: item.isHidden,
          isTop: item.isTop,
        );
      }).toList();
    }

    final defaultMenu = storage.defaultMenu;
    final newDefault = await patched(defaultMenu);
    final defaultChanged = defaultMenu.asMap().entries.any(
      (e) => e.value.imageUrl != newDefault[e.key].imageUrl,
    );
    if (defaultChanged) {
      await storage.saveDefaultMenu(newDefault);
    }

    final overrides = storage.cafeMenuOverrides;
    for (final entry in overrides.entries) {
      final newList = await patched(entry.value);
      final changed = entry.value.asMap().entries.any(
        (e) => e.value.imageUrl != newList[e.key].imageUrl,
      );
      if (changed) {
        await storage.saveCafeMenuOverride(entry.key, newList);
      }
    }
  }

  Future<void> _removeLegacyAlternativeMilkData() async {
    const removedAddonIds = {legacyAlternativeMilkAddonId, 'milk_plant'};

    List<MenuItem> cleanedMenu(List<MenuItem> source) {
      return source
          .map(
            (item) => MenuItem(
              id: item.id,
              category: item.category,
              name: item.name,
              basePrice: item.basePrice,
              description: item.description,
              nutrition: item.nutrition,
              sizes: item.sizes,
              addons: item.addons
                  .where((addon) => !removedAddonIds.contains(addon.id))
                  .toList(),
              showNutrition: item.showNutrition,
              imageUrl: item.imageUrl,
              isHidden: item.isHidden,
              isTop: item.isTop,
            ),
          )
          .toList();
    }

    final cleanedDefaultMenu = cleanedMenu(storage.defaultMenu);
    await storage.saveDefaultMenu(cleanedDefaultMenu);

    final cleanedGlobalAddons = storage.globalAddons
        .where((addon) => !removedAddonIds.contains(addon.id))
        .toList();
    await storage.saveGlobalAddons(cleanedGlobalAddons);

    final overrides = storage.cafeMenuOverrides;
    for (final entry in overrides.entries) {
      await storage.saveCafeMenuOverride(entry.key, cleanedMenu(entry.value));
    }
  }

  // -------- Menu --------
  List<MenuItem> get menu {
    final baseMenu = allMenuItems;
    if (identical(_menuCacheBaseIdentity, baseMenu) && _menuCache != null) {
      return _menuCache!;
    }

    final list = _isAdmin
        ? baseMenu
        : List<MenuItem>.unmodifiable(
            baseMenu.where((x) => x.category != MenuCategory.addons),
          );
    _menuCacheBaseIdentity = baseMenu;
    _menuCache = list;
    return list;
  }

  List<MenuItem> get allMenuItems {
    final overrides = storage.cafeMenuOverrides;
    final source =
        overrides.containsKey(cafe.id) && overrides[cafe.id]!.isNotEmpty
        ? overrides[cafe.id]!
        : storage.defaultMenu;

    if (_allMenuItemsCache != null &&
        identical(_allMenuItemsCacheSource, source) &&
        _allMenuItemsCacheIsAdmin == _isAdmin) {
      return _allMenuItemsCache!;
    }

    final list = _isAdmin
        ? source
        : List<MenuItem>.unmodifiable(source.where((x) => !x.isHidden));
    _allMenuItemsCache = list;
    _allMenuItemsCacheSource = source;
    _allMenuItemsCacheIsAdmin = _isAdmin;
    return list;
  }

  List<MenuItem> get addonItems =>
      allMenuItems.where((x) => x.category == MenuCategory.addons).toList();

  MenuItem? findMenuItemById(String id) {
    final matches = allMenuItems.where((m) => m.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  // -------- Global addons --------
  List<MenuAddon> get globalAddons => storage.globalAddons;

  Future<void> saveGlobalAddons(List<MenuAddon> addons) async {
    final cloudSync = _requireCloudSync();
    final nextData = MenuSeedData(
      menu: List<MenuItem>.from(allMenuItems),
      globalAddons: List<MenuAddon>.from(addons),
      promoCodes: List<PromoCode>.from(_promoCodes),
    );
    await cloudSync.saveMenuSeed(cafeId: cafe.id, data: nextData);
    await storage.saveGlobalAddons(addons);
    notifyListeners();
  }

  Future<void> savePromoCodes(List<PromoCode> promoCodes) async {
    final cloudSync = _requireCloudSync();
    final nextPromoCodes = List<PromoCode>.from(promoCodes);
    final nextData = MenuSeedData(
      menu: List<MenuItem>.from(allMenuItems),
      globalAddons: List<MenuAddon>.from(storage.globalAddons),
      promoCodes: nextPromoCodes,
    );
    await cloudSync.saveMenuSeed(cafeId: cafe.id, data: nextData);
    _promoCodes = nextPromoCodes;
    await storage.savePromoCodes(_promoCodes);
    _revalidateAppliedPromo();
    notifyListeners();
  }

  Future<void> saveMenuConfiguration({
    required List<MenuItem> menuItems,
    required List<MenuAddon> globalAddons,
    required List<PromoCode> promoCodes,
  }) async {
    final cloudSync = _requireCloudSync();
    final nextMenuItems = List<MenuItem>.from(menuItems);
    final nextGlobalAddons = List<MenuAddon>.from(globalAddons);
    final nextPromoCodes = List<PromoCode>.from(promoCodes);
    final nextData = MenuSeedData(
      menu: nextMenuItems,
      globalAddons: nextGlobalAddons,
      promoCodes: nextPromoCodes,
    );

    await cloudSync.saveMenuSeed(cafeId: cafe.id, data: nextData);

    await storage.saveCafeMenuOverride(cafe.id, nextMenuItems);
    await storage.saveGlobalAddons(nextGlobalAddons);
    _promoCodes = nextPromoCodes;
    await storage.savePromoCodes(_promoCodes);
    _revalidateAppliedPromo();
    _invalidateMenuCaches();
    notifyListeners();
  }

  PromoCode? _promoById(String id) {
    final matches = _promoCodes.where((promo) => promo.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  PromoCode? _promoByCode(String normalizedCode) {
    final matches = _promoCodes.where((promo) => promo.code == normalizedCode);
    return matches.isEmpty ? null : matches.first;
  }

  bool _isPromoUsableByCurrentUser(PromoCode promo) {
    final current = _currentUser;
    if (current == null) return false;
    return promo.canBeUsedBy(current.id);
  }

  void _ensurePromoCanBeUsedByCurrentUser(PromoCode promo) {
    final current = _currentUser;
    if (current == null) throw Exception("AUTH_REQUIRED");
    if (!promo.isActive) throw Exception("PROMO_INACTIVE");
    if (promo.hasBeenUsedBy(current.id)) throw Exception("PROMO_ALREADY_USED");
    if (promo.isExhausted) throw Exception("PROMO_LIMIT_REACHED");
  }

  void _revalidateAppliedPromo() {
    final appliedPromoId = _appliedPromoId;
    if (appliedPromoId == null) return;

    final promo = _promoById(appliedPromoId);
    if (promo == null || !_isPromoUsableByCurrentUser(promo)) {
      _appliedPromoId = null;
    }
  }

  void applyPromoCode(String rawCode) {
    if (_currentUser == null) throw Exception("AUTH_REQUIRED");

    final normalizedCode = normalizePromoCode(rawCode);
    if (normalizedCode.isEmpty) throw Exception("PROMO_EMPTY");

    final promo = _promoByCode(normalizedCode);
    if (promo == null) throw Exception("PROMO_NOT_FOUND");

    _ensurePromoCanBeUsedByCurrentUser(promo);
    _appliedPromoId = promo.id;
    notifyListeners();
  }

  void removeAppliedPromo() {
    if (_appliedPromoId == null) return;
    _appliedPromoId = null;
    notifyListeners();
  }

  PromoCode? get appliedPromo {
    final appliedPromoId = _appliedPromoId;
    if (appliedPromoId == null) return null;

    final promo = _promoById(appliedPromoId);
    if (promo == null || !_isPromoUsableByCurrentUser(promo)) {
      return null;
    }
    return promo;
  }

  PromoCode? _resolveAppliedPromoForCheckout() {
    final appliedPromoId = _appliedPromoId;
    if (appliedPromoId == null) return null;

    final promo = _promoById(appliedPromoId);
    if (promo == null) throw Exception("PROMO_NOT_FOUND");

    _ensurePromoCanBeUsedByCurrentUser(promo);
    return promo;
  }

  List<MenuAddon> addonsForItem(MenuItem item) => item.addons;

  Future<void> saveCafeMenu(List<MenuItem> items) async {
    await storage.saveCafeMenuOverride(cafe.id, items);
    _invalidateMenuCaches();
    await _syncMenuSeedToCloud();
    notifyListeners();
  }

  // -------- Cart --------
  Future<void> addToCart(
    MenuItem item, {
    String? sizeId,
    List<String> addonIds = const [],
    List<CartLineAddon> attachedAddons = const [],
    int qty = 1,
  }) async {
    _cart ??= Cart(cafeId: cafe.id);
    final cart = _cart!;
    if (cart.cafeId != cafe.id) {
      _cart = Cart(cafeId: cafe.id);
    }

    for (int i = 0; i < qty; i++) {
      final line = CartLine(
        menuItemId: item.id,
        qty: 1,
        sizeId: sizeId,
        addonIds: addonIds,
        attachedAddons: attachedAddons,
      );

      final key = line.key;
      if (cart.linesByKey.containsKey(key)) {
        cart.linesByKey[key]!.qty += 1;
      } else {
        cart.linesByKey[key] = line;
      }
    }

    await storage.saveCart(cart);
    notifyListeners();
  }

  void changeQty(String lineKey, int delta) {
    final cart = _cart;
    if (cart == null) return;
    final line = cart.linesByKey[lineKey];
    if (line == null) return;

    line.qty += delta;
    if (line.qty <= 0) {
      cart.linesByKey.remove(lineKey);
    }

    storage.saveCart(cart);
    notifyListeners();
  }

  double lineTotal(CartLine line) {
    final item = findMenuItemById(line.menuItemId);
    if (item == null) return 0;

    final sizeDelta = (line.sizeId == null)
        ? 0.0
        : (item.sizes.where((s) => s.id == line.sizeId).isEmpty
              ? 0.0
              : item.sizes.firstWhere((s) => s.id == line.sizeId).priceDelta);

    final addonsSource = addonsForItem(item);
    final addonsTotal = addonsSource
        .where((a) => line.addonIds.contains(a.id))
        .fold<double>(0.0, (sum, a) => sum + a.price);

    final attachedAddonsTotal = line.attachedAddons.fold<double>(0.0, (
      sum,
      attached,
    ) {
      final addonItem = findMenuItemById(attached.menuItemId);
      if (addonItem == null) return sum;
      return sum + (addonItem.basePrice * attached.qty);
    });

    return (item.basePrice + sizeDelta + addonsTotal + attachedAddonsTotal) *
        line.qty;
  }

  double get cartTotal {
    final cart = _cart;
    if (cart == null) return 0;
    return cart.linesByKey.values.fold<double>(
      0.0,
      (sum, l) => sum + lineTotal(l),
    );
  }

  double get cartDiscountAmount {
    final promo = appliedPromo;
    if (promo == null) return 0;
    return promo.discountAmountFor(cartTotal);
  }

  double get cartTotalAfterDiscount =>
      (cartTotal - cartDiscountAmount).clamp(0, double.infinity).toDouble();

  DateTime orderOpenTimeFor(DateTime date) =>
      DateTime(date.year, date.month, date.day, 12, 0);

  DateTime firstPickupTimeFor(DateTime date) =>
      DateTime(date.year, date.month, date.day, 12, 10);

  DateTime orderCloseTimeFor(DateTime date) =>
      DateTime(date.year, date.month, date.day, 21, 50);

  bool isOrderingOpen([DateTime? now]) {
    final value = now ?? DateTime.now();
    final opensAt = orderOpenTimeFor(value);
    final closesAt = orderCloseTimeFor(value);
    return !value.isBefore(opensAt) && !value.isAfter(closesAt);
  }

  bool isPickupTimeAllowed(DateTime pickupTime, [DateTime? now]) {
    final value = now ?? DateTime.now();
    if (pickupTime.year != value.year ||
        pickupTime.month != value.month ||
        pickupTime.day != value.day) {
      return false;
    }
    if (pickupTime.minute % 10 != 0) return false;
    final earliest = firstPickupTimeFor(value);
    final latest = orderCloseTimeFor(value);
    if (pickupTime.isBefore(earliest) || pickupTime.isAfter(latest)) {
      return false;
    }
    return true;
  }

  // -------- Checkout / Orders --------
  Future<void> checkout({
    required DateTime pickupTime,
    required String comment,
  }) async {
    if (_currentUser == null) throw Exception("AUTH_REQUIRED");
    if (!isOrderingOpen()) throw Exception("ORDERING_CLOSED");
    if (!isPickupTimeAllowed(pickupTime)) {
      throw Exception("INVALID_PICKUP_TIME");
    }

    final cart = _cart;
    if (cart == null || cart.isEmpty) return;
    final subtotalAmount = cartTotal;
    final promo = _resolveAppliedPromoForCheckout();
    final discountAmount = promo?.discountAmountFor(subtotalAmount) ?? 0;
    final totalAmount = (subtotalAmount - discountAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final notificationTokens = await _notificationTokensForCheckout();

    final items = cart.linesByKey.values
        .map(
          (l) => OrderItem(
            menuItemId: l.menuItemId,
            qty: l.qty,
            sizeId: l.sizeId,
            addonIds: l.addonIds,
            attachedAddons: l.attachedAddons
                .map(
                  (addon) => OrderItemAddon(
                    menuItemId: addon.menuItemId,
                    qty: addon.qty,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final order = Order(
      id: _uuid.v4(),
      cafeId: cafe.id,
      customerFirstName: _currentUser?.firstName ?? "",
      customerLastName: _currentUser?.lastName ?? "",
      customerPhone: _currentUser?.phone ?? "",
      createdAt: DateTime.now(),
      pickupTime: pickupTime,
      comment: comment,
      items: items,
      status: OrderStatus.accepted,
      userId: _currentUser?.id,
      subtotalAmount: subtotalAmount,
      totalAmount: totalAmount,
      appliedPromo: promo == null
          ? null
          : AppliedPromo(
              code: promo.code,
              discountType: promo.discountType,
              discountValue: promo.discountValue,
              discountAmount: discountAmount,
            ),
      notificationTokens: notificationTokens,
    );

    _orders.insert(0, order);
    await storage.saveOrders(_orders);
    await _cloudSync?.upsertOrder(cafeId: cafe.id, order: order);

    if (promo != null) {
      final currentUserId = _currentUser!.id;
      _promoCodes = _promoCodes.map((item) {
        if (item.id != promo.id) return item;
        return item.copyWith(
          usedByUserIds: [...item.usedByUserIds, currentUserId],
        );
      }).toList();
      await storage.savePromoCodes(_promoCodes);
    }

    _cart = Cart(cafeId: cafe.id);
    await storage.saveCart(_cart);
    _appliedPromoId = null;

    notifyListeners();
  }

  bool canUserCancel(Order o) {
    if (_currentUser == null) return false;
    if (o.userId != _currentUser!.id) return false;
    if (!o.isActive) return false;

    final deadline = o.pickupTime.subtract(const Duration(minutes: 5));
    return DateTime.now().isBefore(deadline);
  }

  Future<void> userCancelOrder(String orderId) async {
    if (_currentUser == null) throw Exception("AUTH_REQUIRED");

    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    final o = _orders[idx];
    if (!canUserCancel(o)) throw Exception("CANCEL_NOT_ALLOWED");

    _orders[idx].status = OrderStatus.cancelled;
    await storage.saveOrders(_orders);
    await _cloudSync?.updateOrderStatus(
      cafeId: cafe.id,
      orderId: orderId,
      status: OrderStatus.cancelled,
    );
    notifyListeners();
  }

  List<Order> get activeOrdersForCurrentUserSelectedCafe {
    if (_currentUser == null) return [];
    final uid = _currentUser!.id;
    final list = _orders.where((o) => o.userId == uid && o.isActive).toList();
    list.sort((a, b) => a.pickupTime.compareTo(b.pickupTime));
    return list;
  }

  List<Order> get activeOrdersForSelectedCafeAdmin {
    if (!_isAdmin) return [];
    final list = _orders
        .where((o) => o.cafeId == cafe.id && o.isActive)
        .toList();

    int rank(OrderStatus s) {
      switch (s) {
        case OrderStatus.ready:
          return 0;
        case OrderStatus.preparing:
          return 1;
        case OrderStatus.accepted:
          return 2;
        default:
          return 3;
      }
    }

    list.sort((a, b) {
      final r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;
      return a.pickupTime.compareTo(b.pickupTime);
    });

    return list;
  }

  List<Order> get historyOrdersForUser {
    if (_currentUser == null) return [];
    final id = _currentUser!.id;
    final list = _orders
        .where(
          (o) =>
              o.userId == id &&
              (o.status == OrderStatus.completed ||
                  o.status == OrderStatus.cancelled),
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // -------- Auth --------
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final users = storage.users;

    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      throw Exception("EMAIL_EXISTS");
    }

    final u = AppUser(
      id: _uuid.v4(),
      email: email,
      passwordHash: _hash(password),
      firstName: name,
    );

    users.add(u);
    await storage.saveUsers(users);

    _currentUser = u;
    await storage.setSessionUserId(u.id);

    _loadFavoritesForCurrentUser();
    _appliedPromoId = null;
    await _restartCloudSync();
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final users = storage.users;
    final match = users
        .where((u) => u.email.toLowerCase() == email.toLowerCase())
        .toList();

    if (match.isEmpty) throw Exception("NOT_FOUND");

    final ok = match.first.passwordHash == _hash(password);
    if (!ok) throw Exception("BAD_PASSWORD");

    _currentUser = match.first;
    await storage.setSessionUserId(_currentUser!.id);

    _loadFavoritesForCurrentUser();
    _appliedPromoId = null;
    await _restartCloudSync();
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _isAdmin = false;
    _setFavoriteIds(<String>{});
    _appliedPromoId = null;
    await storage.setSessionUserId(null);
    _invalidateMenuCaches();
    await _restartCloudSync();
    notifyListeners();
  }

  Future<void> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String? gender,
    DateTime? birthDate,
    String? photoDataUri,
  }) async {
    final current = _currentUser;
    if (current == null) throw Exception("AUTH_REQUIRED");

    final normalizedEmail = email.trim();
    final users = storage.users;
    final emailTaken = users.any(
      (u) =>
          u.id != current.id &&
          u.email.toLowerCase() == normalizedEmail.toLowerCase(),
    );
    if (emailTaken) throw Exception("EMAIL_EXISTS");

    final nextBirthDateIso =
        current.birthDateIso ??
        (birthDate == null
            ? null
            : DateTime(
                birthDate.year,
                birthDate.month,
                birthDate.day,
              ).toIso8601String());

    final updated = current.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      email: normalizedEmail,
      photoDataUri: photoDataUri,
      gender: gender,
      birthDateIso: nextBirthDateIso,
    );

    final updatedUsers = users
        .map((u) => u.id == current.id ? updated : u)
        .toList();
    await storage.saveUsers(updatedUsers);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = _currentUser;
    if (current == null) throw Exception("AUTH_REQUIRED");

    var nextEnabled = enabled;
    if (enabled) {
      final token = await _firebaseBootstrapService?.enableMessaging(
        requestPermission: true,
      );
      if (token == null || token.trim().isEmpty) {
        nextEnabled = false;
      }
    }

    final updated = current.copyWith(notificationsEnabled: nextEnabled);
    final updatedUsers = storage.users
        .map((u) => u.id == current.id ? updated : u)
        .toList();
    await storage.saveUsers(updatedUsers);
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> deleteCurrentAccount() async {
    final current = _currentUser;
    if (current == null) throw Exception("AUTH_REQUIRED");

    final updatedUsers = storage.users
        .where((u) => u.id != current.id)
        .toList();
    await storage.saveUsers(updatedUsers);
    await storage.deleteFavoritesForUser(current.id);
    _currentUser = null;
    _setFavoriteIds(<String>{});
    _isAdmin = false;
    _appliedPromoId = null;
    await storage.setSessionUserId(null);
    _invalidateMenuCaches();
    notifyListeners();
  }

  // -------- Admin --------
  bool adminLogin({required String login, required String password}) {
    final ok =
        (login == cafe.adminLogin) &&
        (cafe.adminPasswordHash == _hash(password));
    _isAdmin = ok;
    _invalidateMenuCaches();
    unawaited(_restartCloudSync());
    notifyListeners();
    return ok;
  }

  void adminLogout() {
    _isAdmin = false;
    _invalidateMenuCaches();
    unawaited(_restartCloudSync());
    notifyListeners();
  }

  Future<void> adminSetOrderStatus(String orderId, OrderStatus status) async {
    if (!_isAdmin) return;

    final idx = _orders.indexWhere(
      (o) => o.id == orderId && o.cafeId == cafe.id,
    );
    if (idx == -1) return;

    _orders[idx].status = status;
    await storage.saveOrders(_orders);
    await _cloudSync?.updateOrderStatus(
      cafeId: cafe.id,
      orderId: orderId,
      status: status,
    );
    notifyListeners();
  }

  Future<bool> adminLoginByCredentials({
    required String login,
    required String password,
  }) async {
    return adminLogin(login: login, password: password);
  }

  @override
  void dispose() {
    _cloudSync?.stop();
    _firebaseBootstrapService?.dispose();
    super.dispose();
  }

  List<MenuItem> _demoMenu() => [
    MenuItem(
      id: "builder_custom",
      category: MenuCategory.constructor,
      name: "Собери свой напиток сам",
      basePrice: 9.0,
      description: "Создай свой напиток в 4 шага",
      nutrition: const Nutrition(kcal: 0, protein: 0, fat: 0, carbs: 0),
      sizes: const [
        MenuSize(id: "size_500", label: "M", volumeMl: 500, priceDelta: 0),
        MenuSize(id: "size_700", label: "L", volumeMl: 700, priceDelta: 1),
      ],
      addons: const [
        // Этап 1 — основа
        MenuAddon(id: "base_raf", name: "Раф", price: 0),
        MenuAddon(id: "base_latte", name: "Латте", price: 0),
        MenuAddon(id: "base_cappuccino", name: "Капучино", price: 0),
        MenuAddon(id: "base_bumble", name: "Бамбл", price: 0),
        MenuAddon(id: "base_espresso_tonic", name: "Эспрессо тоник", price: 0),

        // Этап 2 — концентрат (+2)
        MenuAddon(
          id: "conc_cinnamon_roll",
          name: "Булочка с корицей",
          price: 2,
        ),
        MenuAddon(id: "conc_hazelnut", name: "Лесной орех", price: 2),
        MenuAddon(id: "conc_strawberry", name: "Клубника", price: 2),
        MenuAddon(id: "conc_caramel", name: "Карамель", price: 2),
        MenuAddon(id: "conc_lavender", name: "Лаванда", price: 2),
        MenuAddon(id: "conc_raspberry", name: "Малина", price: 2),
        MenuAddon(id: "conc_popcorn", name: "Попкорн", price: 2),
        MenuAddon(id: "conc_vanilla", name: "Ваниль", price: 2),
        MenuAddon(id: "conc_cherry", name: "Вишня", price: 2),
        MenuAddon(id: "conc_peach", name: "Персик", price: 2),
        MenuAddon(id: "conc_coconut", name: "Кокос", price: 2),
        MenuAddon(id: "conc_mango", name: "Манго", price: 2),
        MenuAddon(id: "conc_almond", name: "Миндаль", price: 2),
        MenuAddon(id: "conc_bubble_gum", name: "Бабл гам", price: 2),
        MenuAddon(id: "conc_watermelon", name: "Арбуз", price: 2),
        MenuAddon(id: "conc_lychee", name: "Личи", price: 2),
        MenuAddon(id: "conc_toffee", name: "Ирис", price: 2),
        MenuAddon(id: "conc_mint", name: "Мята", price: 2),

        // Этап 3 — топпинг (+1)
        MenuAddon(id: "top_caramel", name: "Карамель", price: 1),
        MenuAddon(id: "top_chocolate", name: "Шоколад", price: 1),

        // Этап 4 — bubble-добавка (+3)
        MenuAddon(id: "bubble_tapioca", name: "Тапиока", price: 3),
        MenuAddon(
          id: "bubble_crystal_boba",
          name: "Хрустальная боба",
          price: 3,
        ),
        MenuAddon(id: "bubble_brown_boba", name: "Коричневая боба", price: 3),
        MenuAddon(id: "bubble_cheese_foam", name: "Сырная пенка", price: 3),
        MenuAddon(id: "bubble_jelly_grape", name: "Желе виноград", price: 3),
        MenuAddon(
          id: "bubble_jelly_strawberry",
          name: "Желе клубника",
          price: 3,
        ),
        MenuAddon(id: "bubble_jelly_coconut", name: "Желе кокос", price: 3),
        MenuAddon(id: "bubble_jelly_peach", name: "Желе персик", price: 3),
        MenuAddon(id: "bubble_jelly_mango", name: "Желе манго", price: 3),
      ],
      imageUrl:
          "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),

    MenuItem(
      id: "milk_1",
      category: MenuCategory.milkBase,
      name: "Матча латте",
      basePrice: 7.50,
      description: "Описание позже заменим.",
      nutrition: const Nutrition(kcal: 180, protein: 6, fat: 7, carbs: 22),
      sizes: const [
        MenuSize(id: "s250", label: "M", volumeMl: 250, priceDelta: 0),
        MenuSize(id: "s350", label: "L", volumeMl: 350, priceDelta: 1.5),
      ],
      imageUrl:
          "https://images.unsplash.com/photo-1515823064-d6e0c04616a7?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),

    MenuItem(
      id: "fc_1",
      category: MenuCategory.fruitCream,
      name: "Клубничный крем",
      basePrice: 9.00,
      description: "Описание позже заменим.",
      nutrition: const Nutrition(kcal: 220, protein: 3, fat: 5, carbs: 40),
      sizes: const [],
      imageUrl:
          "https://images.unsplash.com/photo-1481391032119-d89fee407e44?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),

    MenuItem(
      id: "bc_1",
      category: MenuCategory.bubbleCoffee,
      name: "Bubble latte",
      basePrice: 10.00,
      description: "Описание позже заменим.",
      nutrition: const Nutrition(kcal: 250, protein: 4, fat: 6, carbs: 44),
      sizes: const [],
      imageUrl:
          "https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),

    MenuItem(
      id: "ft_1",
      category: MenuCategory.matcha,
      name: "Матча манго",
      basePrice: 8.50,
      description: "Описание позже заменим.",
      nutrition: const Nutrition(kcal: 120, protein: 0, fat: 0, carbs: 28),
      sizes: const [],
      imageUrl:
          "https://images.unsplash.com/photo-1515823064-d6e0c04616a7?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),

    MenuItem(
      id: "lem_1",
      category: MenuCategory.fruitTea,
      name: "Манго чай",
      basePrice: 8.50,
      description: "Описание позже заменим.",
      nutrition: const Nutrition(kcal: 120, protein: 0, fat: 0, carbs: 28),
      sizes: const [],
      imageUrl:
          "https://images.unsplash.com/photo-1497534446932-c925b458314e?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),

    MenuItem(
      id: "coffee_1",
      category: MenuCategory.coffee,
      name: "Американо",
      basePrice: 5.50,
      description: "Описание позже заменим.",
      nutrition: const Nutrition(kcal: 5, protein: 0, fat: 0, carbs: 1),
      sizes: const [],
      addons: const [
        MenuAddon(id: "coffee_syrup_vanilla", name: "Ваниль", price: 1.5),
        MenuAddon(id: "coffee_syrup_caramel", name: "Карамель", price: 1.5),
        MenuAddon(id: "coffee_syrup_mint", name: "Мята", price: 1.5),
        MenuAddon(id: "coffee_syrup_lavender", name: "Лаванда", price: 1.5),
        MenuAddon(id: "coffee_syrup_almond", name: "Миндаль", price: 1.5),
        MenuAddon(id: "coffee_syrup_popcorn", name: "Попкорн", price: 1.5),
        MenuAddon(id: "coffee_syrup_toffee", name: "Тоффи", price: 1.5),
        MenuAddon(id: "coffee_syrup_cinnabon", name: "Синнабон", price: 1.5),
        MenuAddon(id: "coffee_syrup_pistachio", name: "Фисташка", price: 1.5),
        MenuAddon(id: "coffee_syrup_tiramisu", name: "Тирамису", price: 1.5),
        MenuAddon(id: "coffee_syrup_hazelnut", name: "Лесной орех", price: 1.5),
        MenuAddon(
          id: "coffee_topping_caramel",
          name: "Топинг карамель",
          price: 1.5,
        ),
        MenuAddon(
          id: "coffee_topping_chocolate",
          name: "Топинг шоколад",
          price: 1.5,
        ),
      ],
      imageUrl:
          "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80",
      showNutrition: true,
      isHidden: false,
    ),
  ];
}
