import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/menu.dart';
import '../ui/app_item_image.dart';
import '../ui/app_notice.dart';
import 'build_drink_screen.dart';
import 'product_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthed = context.select<AppState, bool>((s) => s.isAuthed);

    if (!isAuthed) {
      return const Scaffold(
        body: Center(child: Text("Войдите в аккаунт, чтобы видеть Любимое")),
      );
    }

    final fav = context.select<AppState, List<MenuItem>>(
      (s) => s.favoriteMenuItems,
    );
    return Scaffold(
      appBar: AppBar(title: const Text("Любимое")),
      body: fav.isEmpty
          ? const _EmptyFavoritesState()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemCount: fav.length,
              itemBuilder: (_, i) =>
                  _ProductCard(key: ValueKey(fav[i].id), item: fav[i]),
            ),
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  const _EmptyFavoritesState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 72, color: scheme.primary),
            const SizedBox(height: 24),
            Text(
              "Любимые блюда",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              "Сохраняй для быстрого доступа",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MenuItem item;

  const _ProductCard({super.key, required this.item});

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
                            color: isDark
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
