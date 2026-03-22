import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  static String _fmtTime(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.hour)}:${two(t.minute)}";
  }

  static String _fmtDate(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.day)}.${two(t.month)}.${t.year}";
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final history = s.historyOrdersForUser;

    return Scaffold(
      appBar: AppBar(title: const Text("История заказов")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (history.isEmpty)
            const Text("Пока нет завершённых заказов")
          else
            ...history.map((o) {
              return Card(
                child: ListTile(
                  title: Text("Заказ #${o.id.substring(0, 6)}"),
                  subtitle: Text(
                    "${s.cafe.name} • Дата: ${_fmtDate(o.createdAt)} • Самовывоз: ${_fmtTime(o.pickupTime)}",
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
            }),
        ],
      ),
    );
  }
}
