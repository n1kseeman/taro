import 'package:flutter_test/flutter_test.dart';
import 'package:taro/models/promo_code.dart';

void main() {
  test('fixed promo discount is capped by subtotal', () {
    final promo = PromoCode(
      id: 'promo_fixed',
      code: 'SAVE5',
      discountType: PromoDiscountType.fixedAmount,
      discountValue: 5,
      createdAt: DateTime(2026, 3, 21),
    );

    expect(promo.discountAmountFor(3), 3);
    expect(promo.discountAmountFor(12), 5);
  });

  test('promo usage rules block reused and exhausted codes', () {
    final promo = PromoCode(
      id: 'promo_percent',
      code: 'TAPO10',
      discountType: PromoDiscountType.percent,
      discountValue: 10,
      maxUses: 2,
      usedByUserIds: ['user_1', 'user_2'],
      createdAt: DateTime(2026, 3, 21),
    );

    expect(promo.isExhausted, isTrue);
    expect(promo.canBeUsedBy('user_1'), isFalse);
    expect(promo.canBeUsedBy('user_3'), isFalse);
  });
}
