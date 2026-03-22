enum PromoDiscountType { fixedAmount, percent }

String normalizePromoCode(String value) => value.trim().toUpperCase();

class PromoCode {
  final String id;
  final String code;
  final PromoDiscountType discountType;
  final double discountValue;
  final int? maxUses;
  final List<String> usedByUserIds;
  final bool isActive;
  final DateTime createdAt;

  const PromoCode({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.createdAt,
    this.maxUses,
    this.usedByUserIds = const [],
    this.isActive = true,
  });

  int get usesCount => usedByUserIds.length;

  bool get isExhausted => maxUses != null && usesCount >= maxUses!;

  bool hasBeenUsedBy(String userId) => usedByUserIds.contains(userId);

  bool canBeUsedBy(String userId) =>
      isActive && !isExhausted && !hasBeenUsedBy(userId);

  double discountAmountFor(double subtotal) {
    if (subtotal <= 0) return 0;

    final rawDiscount = switch (discountType) {
      PromoDiscountType.fixedAmount => discountValue,
      PromoDiscountType.percent => subtotal * (discountValue / 100),
    };

    return rawDiscount.clamp(0, subtotal).toDouble();
  }

  PromoCode copyWith({
    String? code,
    PromoDiscountType? discountType,
    double? discountValue,
    Object? maxUses = _sentinel,
    List<String>? usedByUserIds,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return PromoCode(
      id: id,
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxUses: identical(maxUses, _sentinel) ? this.maxUses : maxUses as int?,
      usedByUserIds: usedByUserIds ?? this.usedByUserIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'discountType': discountType.name,
    'discountValue': discountValue,
    'maxUses': maxUses,
    'usedByUserIds': usedByUserIds,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  static PromoCode fromJson(Map<String, dynamic> json) => PromoCode(
    id: json['id'] as String,
    code: normalizePromoCode((json['code'] ?? '') as String),
    discountType: PromoDiscountType.values.firstWhere(
      (type) => type.name == json['discountType'],
      orElse: () => PromoDiscountType.fixedAmount,
    ),
    discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
    maxUses: (json['maxUses'] as num?)?.toInt(),
    usedByUserIds: (json['usedByUserIds'] as List? ?? [])
        .map((value) => value.toString())
        .toList(),
    isActive: (json['isActive'] ?? true) != false,
    createdAt: json['createdAt'] == null
        ? DateTime.now()
        : DateTime.parse(json['createdAt'] as String),
  );
}

const _sentinel = Object();
