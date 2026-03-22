import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../models/menu.dart';
import '../models/order.dart';
import '../models/promo_code.dart';
import 'firebase_bootstrap_service.dart';
import 'menu_seed_service.dart';

typedef MenuSeedListener = Future<void> Function(MenuSeedData data);
typedef OrdersListener = Future<void> Function(List<Order> orders);

class CloudSyncService {
  CloudSyncService(this._bootstrap);

  final FirebaseBootstrapService _bootstrap;

  StreamSubscription<DatabaseEvent>? _configSubscription;
  StreamSubscription<DatabaseEvent>? _menuSubscription;
  StreamSubscription<DatabaseEvent>? _ordersSubscription;

  MenuSeedListener? _menuListener;
  OrdersListener? _ordersListener;

  List<MenuItem>? _remoteMenuItems;
  List<MenuAddon>? _remoteGlobalAddons;
  List<PromoCode>? _remotePromoCodes;

  bool get isAvailable => _bootstrap.isAvailable;

  FirebaseDatabase get _db => FirebaseDatabase.instance;

  Future<bool> start({
    required String cafeId,
    required MenuSeedData initialSeed,
    required bool includeAllOrders,
    String? currentUserId,
    required MenuSeedListener onMenuChanged,
    required OrdersListener onOrdersChanged,
  }) async {
    await stop();
    if (!await _bootstrap.ensureInitialized()) return false;

    _menuListener = onMenuChanged;
    _ordersListener = onOrdersChanged;

    await _seedIfNeeded(cafeId: cafeId, initialSeed: initialSeed);
    await _configRef(cafeId).keepSynced(true);
    await _menuItemsRef(cafeId).keepSynced(true);
    await _ordersRef(cafeId).keepSynced(true);

    _configSubscription = _configRef(cafeId).onValue.listen((event) {
      final data = _mapFromSnapshot(event.snapshot);
      _remoteGlobalAddons = (data['globalAddons'] as List? ?? const [])
          .map((addon) => MenuAddon.fromJson(Map<String, dynamic>.from(addon)))
          .toList();
      _remotePromoCodes = (data['promoCodes'] as List? ?? const [])
          .map((promo) => PromoCode.fromJson(Map<String, dynamic>.from(promo)))
          .toList();
      _emitMenuIfReady();
    });

    _menuSubscription = _menuItemsRef(cafeId)
        .orderByChild('sortOrder')
        .onValue
        .listen((event) {
          final docs = _childEntries(event.snapshot)
            ..sort(
              (a, b) => _sortOrderOf(a.value).compareTo(_sortOrderOf(b.value)),
            );
          _remoteMenuItems = docs
              .map(
                (entry) =>
                    MenuItem.fromJson(_menuDocData(entry.value, entry.key)),
              )
              .toList();
          _emitMenuIfReady();
        });

    if (includeAllOrders) {
      _ordersSubscription = _ordersRef(cafeId)
          .orderByChild('createdAtEpoch')
          .onValue
          .listen((event) {
            final listener = _ordersListener;
            if (listener == null) return;
            final entries = _childEntries(event.snapshot)
              ..sort(
                (a, b) => _createdAtEpochOf(
                  b.value,
                ).compareTo(_createdAtEpochOf(a.value)),
              );
            final orders = entries
                .map((entry) => _orderFromRealtime(entry.value, entry.key))
                .toList();
            unawaited(listener(orders));
          });
    } else if (currentUserId != null && currentUserId.trim().isNotEmpty) {
      _ordersSubscription = _ordersRef(cafeId)
          .orderByChild('userId')
          .equalTo(currentUserId)
          .onValue
          .listen((event) {
            final listener = _ordersListener;
            if (listener == null) return;
            final entries = _childEntries(event.snapshot)
              ..sort(
                (a, b) => _createdAtEpochOf(
                  b.value,
                ).compareTo(_createdAtEpochOf(a.value)),
              );
            final orders = entries
                .map((entry) => _orderFromRealtime(entry.value, entry.key))
                .toList();
            unawaited(listener(orders));
          });
    } else {
      await onOrdersChanged(const []);
    }

    return true;
  }

  Future<void> stop() async {
    await _configSubscription?.cancel();
    await _menuSubscription?.cancel();
    await _ordersSubscription?.cancel();
    _configSubscription = null;
    _menuSubscription = null;
    _ordersSubscription = null;
    _menuListener = null;
    _ordersListener = null;
    _remoteMenuItems = null;
    _remoteGlobalAddons = null;
    _remotePromoCodes = null;
  }

  Future<void> saveMenuSeed({
    required String cafeId,
    required MenuSeedData data,
  }) async {
    if (!await _bootstrap.ensureInitialized()) return;

    final existingItems = _mapFromSnapshot(await _menuItemsRef(cafeId).get());
    final existingIds = existingItems.keys.toSet();
    final nextIds = data.menu.map((item) => item.id).toSet();
    final updates = <String, Object?>{
      'cafes/$cafeId/menu/config/globalAddons': data.globalAddons
          .map((addon) => addon.toJson())
          .toList(),
      'cafes/$cafeId/menu/config/promoCodes': data.promoCodes
          .map((promo) => promo.toJson())
          .toList(),
      'cafes/$cafeId/menu/config/updatedAt': ServerValue.timestamp,
    };

    for (final removedId in existingIds.difference(nextIds)) {
      updates['cafes/$cafeId/menu/items/$removedId'] = null;
    }

    for (int i = 0; i < data.menu.length; i++) {
      final item = data.menu[i];
      final payload = item.toJson()
        ..['sortOrder'] = i
        ..['updatedAt'] = ServerValue.timestamp;
      updates['cafes/$cafeId/menu/items/${item.id}'] = payload;
    }

    await _db.ref().update(updates);
  }

  Future<void> upsertOrder({
    required String cafeId,
    required Order order,
  }) async {
    if (!await _bootstrap.ensureInitialized()) return;
    await _ordersRef(cafeId).child(order.id).set(_orderToRealtime(order));
  }

  Future<void> updateOrderStatus({
    required String cafeId,
    required String orderId,
    required OrderStatus status,
  }) async {
    if (!await _bootstrap.ensureInitialized()) return;
    await _ordersRef(cafeId).child(orderId).update({
      'status': status.name,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> _seedIfNeeded({
    required String cafeId,
    required MenuSeedData initialSeed,
  }) async {
    final menuCheck = await _menuItemsRef(cafeId).limitToFirst(1).get();
    final configCheck = await _configRef(cafeId).get();
    if (menuCheck.value != null && configCheck.value != null) return;
    await saveMenuSeed(cafeId: cafeId, data: initialSeed);
  }

  void _emitMenuIfReady() {
    final listener = _menuListener;
    final menu = _remoteMenuItems;
    final globalAddons = _remoteGlobalAddons;
    final promoCodes = _remotePromoCodes;
    if (listener == null ||
        menu == null ||
        globalAddons == null ||
        promoCodes == null) {
      return;
    }

    unawaited(
      listener(
        MenuSeedData(
          menu: List<MenuItem>.from(menu),
          globalAddons: List<MenuAddon>.from(globalAddons),
          promoCodes: List<PromoCode>.from(promoCodes),
        ),
      ),
    );
  }

  DatabaseReference _configRef(String cafeId) {
    return _db.ref('cafes/$cafeId/menu/config');
  }

  DatabaseReference _menuItemsRef(String cafeId) {
    return _db.ref('cafes/$cafeId/menu/items');
  }

  DatabaseReference _ordersRef(String cafeId) {
    return _db.ref('cafes/$cafeId/orders');
  }

  Map<String, dynamic> _menuDocData(Map<String, dynamic> data, String docId) {
    final next = Map<String, dynamic>.from(data);
    next['id'] = (next['id'] ?? docId) as String;
    next.remove('sortOrder');
    next.remove('updatedAt');
    return next;
  }

  Map<String, dynamic> _orderToRealtime(Order order) {
    final json = order.toJson();
    json['createdAtEpoch'] = order.createdAt.millisecondsSinceEpoch;
    json['pickupTimeEpoch'] = order.pickupTime.millisecondsSinceEpoch;
    json['updatedAt'] = ServerValue.timestamp;
    return json;
  }

  Order _orderFromRealtime(Map<String, dynamic> data, String docId) {
    final next = Map<String, dynamic>.from(data);
    next['id'] = (next['id'] ?? docId) as String;
    next['createdAt'] = _dateTimeFromRealtime(
      next['createdAt'],
      fallbackEpoch: next['createdAtEpoch'],
    ).toIso8601String();
    next['pickupTime'] = _dateTimeFromRealtime(
      next['pickupTime'],
      fallbackEpoch: next['pickupTimeEpoch'],
    ).toIso8601String();
    next.remove('createdAtEpoch');
    next.remove('pickupTimeEpoch');
    next.remove('updatedAt');
    return Order.fromJson(next);
  }

  DateTime _dateTimeFromRealtime(Object? value, {Object? fallbackEpoch}) {
    final epochValue = value is String ? fallbackEpoch : value;
    if (epochValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(epochValue);
    }
    if (epochValue is num) {
      return DateTime.fromMillisecondsSinceEpoch(epochValue.toInt());
    }
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  List<MapEntry<String, Map<String, dynamic>>> _childEntries(
    DataSnapshot snapshot,
  ) {
    return _mapFromSnapshot(snapshot).entries
        .map(
          (entry) => MapEntry(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _mapFromSnapshot(DataSnapshot snapshot) {
    return _mapFromValue(snapshot.value);
  }

  Map<String, dynamic> _mapFromValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeValue(nestedValue)),
      );
    }
    if (value is List) {
      final map = <String, dynamic>{};
      for (int i = 0; i < value.length; i++) {
        final nestedValue = value[i];
        if (nestedValue != null) {
          map['$i'] = _normalizeValue(nestedValue);
        }
      }
      return map;
    }
    return <String, dynamic>{};
  }

  Object? _normalizeValue(Object? value) {
    if (value is Map || value is List) {
      return _jsonSafeValue(value);
    }
    return value;
  }

  Object? _jsonSafeValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _jsonSafeValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_jsonSafeValue).toList();
    }
    return value;
  }

  int _sortOrderOf(Map<String, dynamic> data) {
    return (data['sortOrder'] as num?)?.toInt() ?? 0;
  }

  int _createdAtEpochOf(Map<String, dynamic> data) {
    return (data['createdAtEpoch'] as num?)?.toInt() ?? 0;
  }
}
