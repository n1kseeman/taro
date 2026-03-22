import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/order.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static String _fmt(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.hour)}:${two(t.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.isAuthed) {
      return const Center(
        child: Text("Войдите в аккаунт, чтобы видеть заказы"),
      );
    }

    final list = s.activeOrdersForCurrentUserSelectedCafe;
    if (list.isEmpty) return const Center(child: Text("Активных заказов нет"));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final o = list[i];
        return Card(
          child: ListTile(
            title: Text("Заказ #${o.id.substring(0, 6)}"),
            subtitle: Text("${s.cafe.name} • Самовывоз: ${_fmt(o.pickupTime)}"),
            trailing: _StatusChip(status: o.status),
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
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  Color _colorFor(OrderStatus s) {
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

  String _text(OrderStatus s) {
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

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Chip(
      label: Text(_text(status)),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
}
