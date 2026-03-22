import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/cart.dart';
import '../models/menu.dart';
import '../ui/app_item_image.dart';
import '../ui/app_notice.dart';

class ProductSheet extends StatefulWidget {
  final String menuItemId;
  const ProductSheet({super.key, required this.menuItemId});

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  String? selectedSize;
  final Set<String> selectedAddons = {};
  int qty = 1;

  bool _inited = false;

  static const int maxAddons = 3;

  String _fmtNutrition(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;

    final s = context.read<AppState>();
    final item = s.menu.firstWhere((m) => m.id == widget.menuItemId);
    selectedSize = item.sizes.isNotEmpty ? item.sizes.first.id : null;

    _inited = true;
  }

  double _price(MenuItem item, List<MenuAddon> addonsSource) {
    double sizeDelta = 0;
    if (selectedSize != null && item.sizes.isNotEmpty) {
      final found = item.sizes.where((s) => s.id == selectedSize).toList();
      if (found.isNotEmpty) sizeDelta = found.first.priceDelta;
    }

    final addonsPrice = addonsSource
        .where((a) => selectedAddons.contains(a.id))
        .fold(0.0, (sum, a) => sum + a.price);

    return (item.basePrice + sizeDelta + addonsPrice) * qty;
  }

  void _toggleAddon(BuildContext context, String addonId, bool nextValue) {
    if (nextValue) {
      if (selectedAddons.length >= maxAddons) {
        showAppNotice(
          context,
          "Можно выбрать максимум 3 добавки",
          isError: true,
        );
        return;
      }
      setState(() => selectedAddons.add(addonId));
    } else {
      setState(() => selectedAddons.remove(addonId));
    }
  }

  Future<void> _showAddonsSheetAndAddToCart(
    BuildContext context,
    AppState s,
    MenuItem item,
  ) async {
    final addonItems = s.addonItems.where((addon) => !addon.isHidden).toList();
    final selectedCounts = <String, int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            int totalSelected() =>
                selectedCounts.values.fold(0, (sum, count) => sum + count);

            double addonsTotal() {
              return addonItems.fold<double>(
                0,
                (sum, addon) =>
                    sum + addon.basePrice * (selectedCounts[addon.id] ?? 0),
              );
            }

            void changeCount(MenuItem addon, int delta) {
              final current = selectedCounts[addon.id] ?? 0;
              final next = current + delta;
              if (next < 0) return;
              if (delta > 0 && totalSelected() >= maxAddons) {
                showAppNotice(
                  sheetContext,
                  "Можно выбрать максимум 3 добавки",
                  isError: true,
                );
                return;
              }
              setModalState(() {
                if (next == 0) {
                  selectedCounts.remove(addon.id);
                } else {
                  selectedCounts[addon.id] = next;
                }
              });
            }

            final finalTotal =
                _price(item, s.addonsForItem(item)) + addonsTotal();

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, controller) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Material(
                    color: scheme.surface,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                "Добавки",
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                "${totalSelected()}/$maxAddons",
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: addonItems.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      "Пока нет доступных добавок",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: controller,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                                  itemCount: addonItems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) {
                                    final addon = addonItems[index];
                                    final count = selectedCounts[addon.id] ?? 0;
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: scheme.surface,
                                            ),
                                            child: addon.imageUrl.trim().isEmpty
                                                ? Icon(
                                                    Icons.add_circle_outline,
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  )
                                                : AppItemImage(
                                                    imageUrl: addon.imageUrl,
                                                    fit: BoxFit.contain,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    placeholderIcon:
                                                        Icons.image_outlined,
                                                    placeholderIconSize: 18,
                                                    placeholderColor:
                                                        Colors.transparent,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  addon.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "${addon.basePrice.toStringAsFixed(2)} BYN",
                                                  style: TextStyle(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: scheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: count == 0
                                                      ? null
                                                      : () => changeCount(
                                                          addon,
                                                          -1,
                                                        ),
                                                  icon: const Icon(
                                                    Icons.remove,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 18,
                                                  child: Center(
                                                    child: Text(
                                                      "$count",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () =>
                                                      changeCount(addon, 1),
                                                  icon: const Icon(Icons.add),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.pop(sheetContext, true),
                                child: Text(
                                  "Добавить в корзину • ${finalTotal.toStringAsFixed(2)} BYN",
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await s.addToCart(
      item,
      sizeId: selectedSize,
      addonIds: [...selectedAddons],
      attachedAddons: selectedCounts.entries
          .where((entry) => entry.value > 0)
          .map(
            (entry) => CartLineAddon(menuItemId: entry.key, qty: entry.value),
          )
          .toList(),
      qty: qty,
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    showAppNotice(context, "Добавлено в корзину");
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final item = context.select<AppState, MenuItem>((state) {
      return state.menu.firstWhere((m) => m.id == widget.menuItemId);
    });
    final isAuthed = context.select<AppState, bool>((state) => state.isAuthed);
    final isFavorite = context.select<AppState, bool>((state) {
      return state.isFavorite(widget.menuItemId);
    });
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    final addonsSource = item.addons;
    final visibleAddons = addonsSource;

    final total = _price(item, addonsSource);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (ctx, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: scheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.zero,
                    children: [
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: SizedBox(
                              width: double.infinity,
                              child: AppItemImage(
                                imageUrl: item.imageUrl,
                                placeholderIcon: Icons.local_cafe,
                                placeholderIconSize: 70,
                                placeholderColor: Colors.black.withValues(
                                  alpha: 0.05,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              style: IconButton.styleFrom(
                                backgroundColor: scheme.surface.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: IconButton(
                              onPressed: () async {
                                if (!isAuthed) {
                                  showAppNotice(
                                    context,
                                    "Сначала войдите в аккаунт",
                                    isError: true,
                                  );
                                  return;
                                }
                                await s.toggleFavorite(item.id);
                              },
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite
                                    ? const Color(0xFFE4546B)
                                    : scheme.onSurface,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: isFavorite
                                    ? const Color(
                                        0xFFE4546B,
                                      ).withValues(alpha: 0.14)
                                    : scheme.surface.withValues(alpha: 0.95),
                                side: BorderSide(
                                  color: isFavorite
                                      ? const Color(
                                          0xFFE4546B,
                                        ).withValues(alpha: 0.32)
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.22,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),

                            if (item.description.trim().isNotEmpty)
                              Text(
                                item.description,
                                style: TextStyle(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),

                            if (item.showNutrition) ...[
                              const SizedBox(height: 10),
                              Text(
                                "КБЖУ: ${_fmtNutrition(item.nutrition.kcal)} ккал • "
                                "Б ${item.nutrition.protein} • "
                                "Ж ${item.nutrition.fat} • "
                                "У ${item.nutrition.carbs}",
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            if (item.sizes.isNotEmpty) ...[
                              Text(
                                "Размер",
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: item.sizes.map((sz) {
                                  final selected = sz.id == selectedSize;
                                  final price =
                                      (item.basePrice + sz.priceDelta);

                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => selectedSize = sz.id),
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: sz == item.sizes.last ? 0 : 10,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? scheme.primary
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              "${price.toStringAsFixed(2)} BYN",
                                              style: TextStyle(
                                                color: selected
                                                    ? scheme.onPrimary
                                                    : scheme.onSurface,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              sz.displayLabel,
                                              style: TextStyle(
                                                color: selected
                                                    ? scheme.onPrimary
                                                          .withValues(
                                                            alpha: 0.9,
                                                          )
                                                    : scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),
                            ],

                            if (visibleAddons.isNotEmpty) ...[
                              Text(
                                "Добавки",
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Максимум: $maxAddons",
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),

                              ...visibleAddons.map((a) {
                                final selected = selectedAddons.contains(a.id);
                                final disabled =
                                    !selected &&
                                    selectedAddons.length >= maxAddons;

                                return Opacity(
                                  opacity: disabled ? 0.45 : 1,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                    title: Text(
                                      a.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "+${a.price.toStringAsFixed(2)} BYN",
                                    ),
                                    trailing: Checkbox(
                                      value: selected,
                                      onChanged: disabled
                                          ? null
                                          : (v) => _toggleAddon(
                                              context,
                                              a.id,
                                              v == true,
                                            ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                ColoredBox(
                  color: scheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          8 + bottomInset,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 16,
                              color: scheme.shadow.withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () => setState(
                                      () => qty = (qty > 1) ? qty - 1 : 1,
                                    ),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  SizedBox(
                                    width: 24,
                                    child: Center(
                                      child: Text(
                                        "$qty",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(
                                      () => qty = (qty < 99) ? qty + 1 : 99,
                                    ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  if (!s.isAuthed) {
                                    showAppNotice(
                                      context,
                                      "Сначала войдите в аккаунт",
                                      isError: true,
                                    );
                                    return;
                                  }
                                  await _showAddonsSheetAndAddToCart(
                                    context,
                                    s,
                                    item,
                                  );
                                },
                                child: Text(
                                  "В корзину • ${total.toStringAsFixed(2)} BYN",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
