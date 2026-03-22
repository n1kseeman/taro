import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/menu.dart';
import '../models/order.dart';
import '../models/promo_code.dart';
import '../ui/app_notice.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.ready:
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _statusText(OrderStatus s) {
    switch (s) {
      case OrderStatus.accepted:
        return "принят";
      case OrderStatus.preparing:
        return "готовится";
      case OrderStatus.ready:
        return "готов";
      case OrderStatus.completed:
        return "выдан";
      case OrderStatus.cancelled:
        return "отменён";
    }
  }

  String _fmtTime(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.hour)}:${two(t.minute)}";
  }

  String _fmtDate(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.day)}.${two(t.month)}.${t.year}";
  }

  List<MenuItem> _menuForOrderCafe(AppState s, String cafeId) {
    final overrides = s.storage.cafeMenuOverrides;
    if (overrides.containsKey(cafeId) && overrides[cafeId]!.isNotEmpty) {
      return overrides[cafeId]!;
    }
    return s.storage.defaultMenu;
  }

  MenuItem? _findMenuItem(List<MenuItem> menu, String id) {
    final matches = menu.where((m) => m.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }

  List<MenuAddon> _addonsForItem(MenuItem item) => item.addons;

  double _orderItemTotal(List<MenuItem> menu, MenuItem item, OrderItem oi) {
    final sizeDelta = (oi.sizeId == null)
        ? 0.0
        : (item.sizes.where((x) => x.id == oi.sizeId).isEmpty
              ? 0.0
              : item.sizes.firstWhere((x) => x.id == oi.sizeId).priceDelta);

    final addonsTotal = _addonsForItem(item)
        .where((a) => oi.addonIds.contains(a.id))
        .fold<double>(0.0, (sum, a) => sum + a.price);
    final attachedAddonsTotal = oi.attachedAddons.fold<double>(0.0, (
      sum,
      addon,
    ) {
      final addonItem = _findMenuItem(menu, addon.menuItemId);
      if (addonItem == null) return sum;
      return sum + (addonItem.basePrice * addon.qty);
    });

    return (item.basePrice + sizeDelta + addonsTotal + attachedAddonsTotal) *
        oi.qty;
  }

  String _formatMoney(double value) => "${value.toStringAsFixed(2)} BYN";

  String _formatPromoValue(AppliedPromo promo) {
    final value = promo.discountValue % 1 == 0
        ? promo.discountValue.toStringAsFixed(0)
        : promo.discountValue.toStringAsFixed(2);
    return promo.discountType == PromoDiscountType.percent
        ? "$value%"
        : "$value BYN";
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final order = s.orders.firstWhere((o) => o.id == orderId);
    final menu = _menuForOrderCafe(s, order.cafeId);

    final color = _statusColor(order.status);

    double calculatedSubtotal = 0;
    for (final oi in order.items) {
      final item = _findMenuItem(menu, oi.menuItemId);
      if (item != null) calculatedSubtotal += _orderItemTotal(menu, item, oi);
    }
    final subtotalAmount = order.subtotalAmount ?? calculatedSubtotal;
    final discountAmount = order.appliedPromo?.discountAmount ?? 0;
    final totalAmount =
        order.totalAmount ??
        (subtotalAmount - discountAmount).clamp(0, double.infinity).toDouble();

    final canCancel = !s.isAdmin && s.canUserCancel(order);
    final isAdminForThisCafe = s.isAdmin && order.cafeId == s.cafe.id;
    final customerName = [
      order.customerFirstName.trim(),
      order.customerLastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    return Scaffold(
      appBar: AppBar(title: Text("Заказ #${order.id.substring(0, 6)}")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.cafe.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(s.cafe.address),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Chip(
                        label: Text(_statusText(order.status)),
                        backgroundColor: color.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                      ),
                      const Spacer(),
                      Text(
                        "${_fmtDate(order.createdAt)} • ${_fmtTime(order.createdAt)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Самовывоз: ${_fmtTime(order.pickupTime)}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isAdminForThisCafe &&
                      (customerName.isNotEmpty ||
                          order.customerPhone.trim().isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (customerName.isNotEmpty) customerName,
                        if (order.customerPhone.trim().isNotEmpty)
                          order.customerPhone.trim(),
                      ].join(" • "),
                    ),
                  ],
                  if (order.comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text("Комментарий: ${order.comment}"),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text("Позиции", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          ...order.items.map((oi) {
            final item = _findMenuItem(menu, oi.menuItemId);
            if (item == null) {
              return Card(
                child: ListTile(
                  title: const Text("Позиция удалена из меню"),
                  subtitle: Text("ID: ${oi.menuItemId} • x${oi.qty}"),
                ),
              );
            }

            String sizeLabel = "";
            if (oi.sizeId != null) {
              final found = item.sizes.where((x) => x.id == oi.sizeId).toList();
              if (found.isNotEmpty) sizeLabel = found.first.displayLabel;
            }

            final addonNames = _addonsForItem(item)
                .where((a) => oi.addonIds.contains(a.id))
                .map((a) => a.name)
                .toList();

            final subtitleParts = <String>[];
            if (sizeLabel.isNotEmpty) subtitleParts.add(sizeLabel);
            if (addonNames.isNotEmpty) {
              subtitleParts.add("Добавки: ${addonNames.join(", ")}");
            }
            final attachedAddonNames = oi.attachedAddons
                .map((addon) {
                  final addonItem = _findMenuItem(menu, addon.menuItemId);
                  if (addonItem == null) return null;
                  return "${addonItem.name} x${addon.qty}";
                })
                .whereType<String>()
                .toList();
            if (attachedAddonNames.isNotEmpty) {
              subtitleParts.add("Допы: ${attachedAddonNames.join(", ")}");
            }

            final lineTotal = _orderItemTotal(menu, item, oi);

            return Card(
              child: ListTile(
                title: Text(item.name),
                subtitle: subtitleParts.isEmpty
                    ? null
                    : Text(subtitleParts.join(" • ")),
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lineTotal.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text("BYN"),
                  ],
                ),
                trailing: Text(
                  "x${oi.qty}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text("Сумма")),
                      Text(
                        _formatMoney(subtotalAmount),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  if (order.appliedPromo != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "Промокод ${order.appliedPromo!.code} (${_formatPromoValue(order.appliedPromo!)})",
                          ),
                        ),
                        Text(
                          "-${discountAmount.toStringAsFixed(2)} BYN",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Итого",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        _formatMoney(totalAmount),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Отменить заказ?"),
                      content: const Text(
                        "Отмена доступна только до 5 минут до времени самовывоза.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Нет"),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Да, отменить"),
                        ),
                      ],
                    ),
                  );

                  if (ok != true) return;

                  try {
                    await s.userCancelOrder(order.id);
                    if (!context.mounted) return;
                    showAppNotice(context, "Заказ отменён");
                    Navigator.pop(context);
                  } catch (_) {
                    if (!context.mounted) return;
                    showAppNotice(
                      context,
                      "Отменить уже нельзя (меньше 5 минут до самовывоза)",
                      isError: true,
                    );
                  }
                },
                child: const Text("Отменить заказ"),
              ),
            ),
          ],

          if (isAdminForThisCafe) ...[
            const SizedBox(height: 18),
            Text("Админ", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<OrderStatus>(
              initialValue: order.status,
              items: const [
                DropdownMenuItem(
                  value: OrderStatus.accepted,
                  child: Text("принят"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.preparing,
                  child: Text("готовится"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.ready,
                  child: Text("готов"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.completed,
                  child: Text("выдан"),
                ),
                DropdownMenuItem(
                  value: OrderStatus.cancelled,
                  child: Text("отменён"),
                ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await s.adminSetOrderStatus(order.id, v);
              },
              decoration: const InputDecoration(
                labelText: "Статус заказа",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
