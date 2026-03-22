import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/order.dart';
import '../order_details_screen.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    if (!s.isAdmin) return const Center(child: Text("Нет доступа"));

    final list = s.activeOrdersForSelectedCafeAdmin;
    if (list.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: const Text("Активных заказов нет"),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final o = list[i];
        final customerName = [
          o.customerFirstName.trim(),
          o.customerLastName.trim(),
        ].where((part) => part.isNotEmpty).join(' ');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              customerName.isEmpty
                  ? "Заказ #${o.id.substring(0, 6)}"
                  : "$customerName • #${o.id.substring(0, 6)}",
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (o.customerPhone.trim().isNotEmpty) o.customerPhone.trim(),
                  "Самовывоз: ${_fmt(o.pickupTime)}",
                  _statusText(o.status),
                ].join(" • "),
              ),
            ),
            trailing: DropdownButton<OrderStatus>(
              value: o.status,
              onChanged: (v) async {
                if (v == null) return;
                await s.adminSetOrderStatus(o.id, v);
              },
              items: OrderStatus.values.map((st) {
                return DropdownMenuItem(
                  value: st,
                  child: Text(_statusText(st)),
                );
              }).toList(),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(orderId: o.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static String _fmt(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  static String _statusText(OrderStatus s) {
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
}
