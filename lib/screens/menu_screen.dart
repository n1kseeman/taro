import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/menu.dart';
import '../ui/app_item_image.dart';
import '../ui/app_notice.dart';
import 'build_drink_screen.dart';
import 'product_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = context.select<AppState, List<MenuItem>>((s) => s.menu);
    final mediaPadding = MediaQuery.of(context).padding;
    final topInset = mediaPadding.top;
    final bottomInset = mediaPadding.bottom;

    final constructorItems = items
        .where((x) => x.category == MenuCategory.constructor)
        .toList();
    final milkBaseItems = items
        .where((x) => x.category == MenuCategory.milkBase)
        .toList();
    final fruitCreamItems = items
        .where((x) => x.category == MenuCategory.fruitCream)
        .toList();
    final bubbleCoffeeItems = items
        .where((x) => x.category == MenuCategory.bubbleCoffee)
        .toList();
    final matchaItems = items
        .where((x) => x.category == MenuCategory.matcha)
        .toList();
    final fruitTeaItems = items
        .where((x) => x.category == MenuCategory.fruitTea)
        .toList();
    final coffeeItems = items
        .where((x) => x.category == MenuCategory.coffee)
        .toList();

    return ListView(
      controller: _controller,
      padding: EdgeInsets.fromLTRB(12, topInset + 74, 12, bottomInset + 84),
      children: [
        const _SectionTitle(
          title: "Конструктор",
          icon: Icons.auto_awesome,
          topSpacing: 0,
        ),
        _ConstructorBlock(items: constructorItems),

        const _SectionTitle(
          title: "Milk Base",
          icon: Icons.local_cafe,
          topSpacing: 24,
        ),
        _Grid(items: milkBaseItems),

        const _SectionTitle(title: "Fruit&Cream", icon: Icons.icecream),
        _Grid(items: fruitCreamItems),

        const _SectionTitle(title: "Bubble coffee", icon: Icons.bubble_chart),
        _Grid(items: bubbleCoffeeItems),

        const _SectionTitle(title: "Matcha", icon: Icons.spa),
        _Grid(items: matchaItems),

        const _SectionTitle(
          title: "Fruit&Tea",
          icon: Icons.emoji_food_beverage,
        ),
        _Grid(items: fruitTeaItems),

        const _SectionTitle(title: "Кофе", icon: Icons.coffee),
        _Grid(items: coffeeItems),

        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final double topSpacing;

  const _SectionTitle({
    required this.title,
    required IconData icon,
    this.topSpacing = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          height: 1,
        ),
      ),
    );
  }
}

class _ConstructorBlock extends StatelessWidget {
  final List<MenuItem> items;

  const _ConstructorBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("Пока нет конструктора"),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final item = items.first;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BuildDrinkScreen()),
        );
      },
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.secondaryContainer],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Собери свой напиток сам",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.92),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      "Открыть конструктор",
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: scheme.onPrimaryContainer,
                size: 42,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<MenuItem> items;

  const _Grid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text("Пока нет позиций"),
      );
    }

    final rows = <List<MenuItem>>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(items.sublist(i, i + 2 > items.length ? items.length : i + 2));
    }

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.6,
                    child: _AnimatedProductCard(
                      key: ValueKey(row.first.id),
                      index: items.indexOf(row.first),
                      item: row.first,
                    ),
                  ),
                ),
                if (row.length == 2) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.6,
                      child: _AnimatedProductCard(
                        key: ValueKey(row[1].id),
                        index: items.indexOf(row[1]),
                        item: row[1],
                      ),
                    ),
                  ),
                ] else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _AnimatedProductCard extends StatelessWidget {
  final int index;
  final MenuItem item;

  const _AnimatedProductCard({
    super.key,
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: 220 + index * 45);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _ProductCard(item: item),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MenuItem item;

  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final isFav = context.select<AppState, bool>((state) {
      return state.isFavorite(item.id);
    });
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoriteColor = const Color(0xFFE4546B);
    final description = item.description.trim();
    final showTopBadge = item.isTop;

    return GestureDetector(
      onTap: () {
        if (item.category == MenuCategory.constructor) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuildDrinkScreen()),
          );
          return;
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProductSheet(menuItemId: item.id),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.025),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageSize,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          child: AppItemImage(
                            imageUrl: item.imageUrl,
                            placeholderIcon: Icons.local_cafe,
                            placeholderIconSize: 44,
                          ),
                        ),
                      ),
                      if (showTopBadge)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3BA55D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "ТОП",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () async {
                            try {
                              await s.toggleFavorite(item.id);
                            } catch (_) {
                              if (!context.mounted) return;
                              showAppNotice(
                                context,
                                "Сначала войдите в аккаунт",
                                isError: true,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isFav
                                  ? favoriteColor.withValues(alpha: 0.16)
                                  : Colors.black.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFav
                                    ? favoriteColor.withValues(alpha: 0.38)
                                    : Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? favoriteColor : Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description.isEmpty
                              ? "Авторский напиток с мягким вкусом"
                              : description,
                          maxLines: 2,
                          overflow: TextOverflow.fade,
                          softWrap: true,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? scheme.primaryContainer.withValues(
                                    alpha: 0.42,
                                  )
                                : scheme.surfaceContainerHighest,
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "от ${item.basePrice.toStringAsFixed(2)} BYN",
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
