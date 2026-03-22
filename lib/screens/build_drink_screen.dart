import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/menu.dart';
import '../ui/app_item_image.dart';
import '../ui/app_notice.dart';

class BuildDrinkScreen extends StatefulWidget {
  const BuildDrinkScreen({super.key});

  @override
  State<BuildDrinkScreen> createState() => _BuildDrinkScreenState();
}

class _BuildDrinkScreenState extends State<BuildDrinkScreen> {
  int step = 0;

  String? selectedSizeId;
  String? selectedBaseId;

  final Set<String> concentrates = {};
  final Set<String> toppings = {};
  final Set<String> bubbles = {};

  static const int maxConcentrates = 2;
  static const int maxToppings = 2;
  static const int maxBubbles = 2;

  MenuItem _item(AppState s) => s.menu.firstWhere(
    (e) => e.id == "builder_custom",
    orElse: () {
      throw Exception("builder_custom not found");
    },
  );

  List<MenuAddon> _stageAddons(MenuItem item, String prefix) {
    return item.addons.where((a) => a.id.startsWith(prefix)).toList();
  }

  double _price(MenuItem item) {
    double total = item.basePrice;

    if (selectedSizeId != null) {
      final selected = item.sizes.where((s) => s.id == selectedSizeId).toList();
      if (selected.isNotEmpty) {
        total += selected.first.priceDelta;
      }
    }

    total += concentrates.length * 2;
    total += toppings.length * 1;
    total += bubbles.length * 3;

    return total;
  }

  String _summary(MenuItem item) {
    final parts = <String>[];

    final sizeLabel = item.sizes
        .firstWhere(
          (s) => s.id == selectedSizeId,
          orElse: () => const MenuSize(id: "", label: "", priceDelta: 0),
        )
        .displayLabel;
    if (sizeLabel.isNotEmpty) parts.add(sizeLabel);

    final base = item.addons
        .where((a) => a.id == selectedBaseId)
        .map((e) => e.name)
        .firstOrNull;
    if (base != null) parts.add(base);

    for (final id in concentrates) {
      final found = item.addons
          .where((a) => a.id == id)
          .map((e) => e.name)
          .firstOrNull;
      if (found != null) parts.add(found);
    }

    for (final id in toppings) {
      final found = item.addons
          .where((a) => a.id == id)
          .map((e) => e.name)
          .firstOrNull;
      if (found != null) parts.add(found);
    }

    for (final id in bubbles) {
      final found = item.addons
          .where((a) => a.id == id)
          .map((e) => e.name)
          .firstOrNull;
      if (found != null) parts.add(found);
    }

    return parts.join(" / ");
  }

  bool get _canNextStep0 => selectedSizeId != null && selectedBaseId != null;

  Future<void> _addToCart(AppState s, MenuItem item) async {
    final addonIds = <String>[
      ...?switch (selectedBaseId) {
        final String baseId => [baseId],
        null => null,
      },
      ...concentrates,
      ...toppings,
      ...bubbles,
    ];

    await s.addToCart(item, sizeId: selectedSizeId, addonIds: addonIds, qty: 1);
  }

  Widget _stepDots(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }

  Widget _optionCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    String imageUrl = "",
    IconData icon = Icons.local_drink,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasSubtitle = subtitle != null && subtitle.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: hasSubtitle ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: hasSubtitle ? 52 : 44,
              height: hasSubtitle ? 52 : 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.trim().isNotEmpty
                  ? _AddonImage(imageUrl: imageUrl)
                  : Icon(
                      icon,
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: hasSubtitle ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: selected
                            ? scheme.onPrimary.withValues(alpha: 0.86)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: scheme.onPrimary),
          ],
        ),
      ),
    );
  }

  Widget _stageBlock({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final item = _item(s);

    final bases = _stageAddons(item, "base_");
    final concs = _stageAddons(item, "conc_");
    final tops = _stageAddons(item, "top_");
    final bubs = _stageAddons(item, "bubble_");

    final price = _price(item);
    final summary = _summary(item);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Собери свой напиток"),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.62),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _stepDots(context),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (step == 0)
                  _stageBlock(
                    context: context,
                    title: "Шаг 1. Основа",
                    subtitle: "Выбери объем и основу",
                    children: [
                      const Text(
                        "Объем",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...item.sizes.map(
                        (size) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _optionCard(
                            context: context,
                            title: size.displayLabel,
                            subtitle:
                                "${(item.basePrice + size.priceDelta).toStringAsFixed(0)} BYN",
                            selected: selectedSizeId == size.id,
                            onTap: () =>
                                setState(() => selectedSizeId = size.id),
                            icon: Icons.local_cafe,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Основа",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...bases.map(
                        (base) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _optionCard(
                            context: context,
                            title: base.name,
                            selected: selectedBaseId == base.id,
                            onTap: () =>
                                setState(() => selectedBaseId = base.id),
                            imageUrl: base.imageUrl,
                            icon: Icons.coffee_maker,
                          ),
                        ),
                      ),
                    ],
                  ),

                if (step == 1)
                  _stageBlock(
                    context: context,
                    title: "Шаг 2. Концентрат",
                    subtitle: "Можно выбрать до 2",
                    children: [
                      ...concs.map((c) {
                        final selected = concentrates.contains(c.id);
                        final disabled =
                            !selected && concentrates.length >= maxConcentrates;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Opacity(
                            opacity: disabled ? 0.45 : 1,
                            child: _optionCard(
                              context: context,
                              title: c.name,
                              subtitle: "+2 BYN",
                              selected: selected,
                              imageUrl: c.imageUrl,
                              onTap: disabled
                                  ? () {}
                                  : () {
                                      setState(() {
                                        if (selected) {
                                          concentrates.remove(c.id);
                                        } else {
                                          concentrates.add(c.id);
                                        }
                                      });
                                    },
                              icon: Icons.icecream,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                if (step == 2)
                  _stageBlock(
                    context: context,
                    title: "Шаг 3. Топпинг",
                    subtitle: "Можно выбрать до 2",
                    children: [
                      ...tops.map((t) {
                        final selected = toppings.contains(t.id);
                        final disabled =
                            !selected && toppings.length >= maxToppings;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Opacity(
                            opacity: disabled ? 0.45 : 1,
                            child: _optionCard(
                              context: context,
                              title: t.name,
                              subtitle: "+1 BYN",
                              selected: selected,
                              imageUrl: t.imageUrl,
                              onTap: disabled
                                  ? () {}
                                  : () {
                                      setState(() {
                                        if (selected) {
                                          toppings.remove(t.id);
                                        } else {
                                          toppings.add(t.id);
                                        }
                                      });
                                    },
                              icon: Icons.water_drop,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                if (step == 3)
                  _stageBlock(
                    context: context,
                    title: "Шаг 4. Bubble-добавка",
                    subtitle: "Можно выбрать до 2",
                    children: [
                      ...bubs.map((b) {
                        final selected = bubbles.contains(b.id);
                        final disabled =
                            !selected && bubbles.length >= maxBubbles;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Opacity(
                            opacity: disabled ? 0.45 : 1,
                            child: _optionCard(
                              context: context,
                              title: b.name,
                              subtitle: "+3 BYN",
                              selected: selected,
                              imageUrl: b.imageUrl,
                              onTap: disabled
                                  ? () {}
                                  : () {
                                      setState(() {
                                        if (selected) {
                                          bubbles.remove(b.id);
                                        } else {
                                          bubbles.add(b.id);
                                        }
                                      });
                                    },
                              icon: Icons.bubble_chart,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Текущая сборка",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.isEmpty ? "Пока ничего не выбрано" : summary,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Итого: ${price.toStringAsFixed(2)} BYN",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.62),
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.28),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: scheme.shadow.withValues(alpha: 0.12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => step -= 1),
                        child: const Text("Назад"),
                      ),
                    ),
                  if (step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () async {
                        if (step == 0) {
                          if (!_canNextStep0) {
                            showAppNotice(
                              context,
                              "Сначала выбери объем и основу",
                              isError: true,
                            );
                            return;
                          }
                          setState(() => step += 1);
                          return;
                        }

                        if (step < 3) {
                          setState(() => step += 1);
                          return;
                        }

                        await _addToCart(s, item);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        showAppNotice(
                          context,
                          "Конструктор добавлен в корзину",
                        );
                      },
                      child: Text(
                        step == 3
                            ? "В корзину • ${price.toStringAsFixed(2)} BYN"
                            : "Далее • ${price.toStringAsFixed(2)} BYN",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddonImage extends StatelessWidget {
  final String imageUrl;

  const _AddonImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AppItemImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      padding: EdgeInsets.all(4),
      placeholderIcon: Icons.image_outlined,
      placeholderIconSize: 18,
      placeholderColor: Colors.transparent,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
