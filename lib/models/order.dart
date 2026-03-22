import 'promo_code.dart';

class OrderItemAddon {
  final String menuItemId;
  final int qty;

  const OrderItemAddon({required this.menuItemId, required this.qty});

  Map<String, dynamic> toJson() => {"menuItemId": menuItemId, "qty": qty};

  static OrderItemAddon fromJson(Map<String, dynamic> j) =>
      OrderItemAddon(menuItemId: j["menuItemId"], qty: j["qty"]);
}

enum OrderStatus { accepted, preparing, ready, completed, cancelled }

class OrderItem {
  final String menuItemId;
  final String? sizeId;
  final List<String> addonIds;
  final List<OrderItemAddon> attachedAddons;
  final int qty;

  const OrderItem({
    required this.menuItemId,
    required this.qty,
    this.sizeId,
    this.addonIds = const [],
    this.attachedAddons = const [],
  });

  Map<String, dynamic> toJson() => {
    "menuItemId": menuItemId,
    "sizeId": sizeId,
    "addonIds": addonIds,
    "attachedAddons": attachedAddons.map((e) => e.toJson()).toList(),
    "qty": qty,
  };

  static OrderItem fromJson(Map<String, dynamic> j) => OrderItem(
    menuItemId: j["menuItemId"],
    sizeId: j["sizeId"],
    addonIds: (j["addonIds"] as List).map((e) => e.toString()).toList(),
    attachedAddons: (j["attachedAddons"] as List? ?? [])
        .map((e) => OrderItemAddon.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    qty: j["qty"],
  );
}

class Order {
  final String id;
  final String cafeId;
  final String? userId;
  final String customerFirstName;
  final String customerLastName;
  final String customerPhone;
  final DateTime createdAt;
  final DateTime pickupTime;
  final String comment;
  OrderStatus status;
  final List<OrderItem> items;
  final double? subtotalAmount;
  final double? totalAmount;
  final AppliedPromo? appliedPromo;
  final List<String> notificationTokens;

  Order({
    required this.id,
    required this.cafeId,
    required this.customerFirstName,
    required this.customerLastName,
    required this.customerPhone,
    required this.createdAt,
    required this.pickupTime,
    required this.comment,
    required this.items,
    required this.status,
    this.userId,
    this.subtotalAmount,
    this.totalAmount,
    this.appliedPromo,
    this.notificationTokens = const [],
  });

  bool get isActive =>
      status != OrderStatus.completed && status != OrderStatus.cancelled;

  Map<String, dynamic> toJson() => {
    "id": id,
    "cafeId": cafeId,
    "userId": userId,
    "customerFirstName": customerFirstName,
    "customerLastName": customerLastName,
    "customerPhone": customerPhone,
    "createdAt": createdAt.toIso8601String(),
    "pickupTime": pickupTime.toIso8601String(),
    "comment": comment,
    "status": status.name,
    "items": items.map((e) => e.toJson()).toList(),
    "subtotalAmount": subtotalAmount,
    "totalAmount": totalAmount,
    "appliedPromo": appliedPromo?.toJson(),
    "notificationTokens": notificationTokens,
  };

  static Order fromJson(Map<String, dynamic> j) => Order(
    id: j["id"],
    cafeId: j["cafeId"],
    userId: j["userId"],
    customerFirstName: (j["customerFirstName"] ?? "") as String,
    customerLastName: (j["customerLastName"] ?? "") as String,
    customerPhone: (j["customerPhone"] ?? "") as String,
    createdAt: DateTime.parse(j["createdAt"]),
    pickupTime: DateTime.parse(j["pickupTime"]),
    comment: j["comment"] ?? "",
    status: OrderStatus.values.firstWhere((s) => s.name == j["status"]),
    items: (j["items"] as List)
        .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    subtotalAmount: (j["subtotalAmount"] as num?)?.toDouble(),
    totalAmount: (j["totalAmount"] as num?)?.toDouble(),
    appliedPromo: j["appliedPromo"] == null
        ? null
        : AppliedPromo.fromJson(
            Map<String, dynamic>.from(j["appliedPromo"] as Map),
          ),
    notificationTokens: (j["notificationTokens"] as List? ?? [])
        .map((token) => token.toString())
        .where((token) => token.trim().isNotEmpty)
        .toList(),
  );
}

class AppliedPromo {
  final String code;
  final PromoDiscountType discountType;
  final double discountValue;
  final double discountAmount;

  const AppliedPromo({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
  });

  Map<String, dynamic> toJson() => {
    "code": code,
    "discountType": discountType.name,
    "discountValue": discountValue,
    "discountAmount": discountAmount,
  };

  static AppliedPromo fromJson(Map<String, dynamic> json) => AppliedPromo(
    code: (json["code"] ?? "") as String,
    discountType: PromoDiscountType.values.firstWhere(
      (type) => type.name == json["discountType"],
      orElse: () => PromoDiscountType.fixedAmount,
    ),
    discountValue: (json["discountValue"] as num?)?.toDouble() ?? 0,
    discountAmount: (json["discountAmount"] as num?)?.toDouble() ?? 0,
  );
}
