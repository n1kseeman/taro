import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/menu.dart';
import 'build_drink_screen.dart';
import 'menu_screen.dart';
import 'product_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

const _chromeAlpha = 0.34;
const _topBarHeight = 50.0;

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Future<void> _openSearch() async {
    final items = context.read<AppState>().menu;
    final item = await showSearch<MenuItem?>(
      context: context,
      delegate: _MenuSearchDelegate(items: items),
    );

    if (!mounted || item == null) return;

    if (item.category == MenuCategory.constructor) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BuildDrinkScreen()),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductSheet(menuItemId: item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    final List<Widget> screens = [
      const MenuScreen(),
      CartScreen(onOpenMenu: () => setState(() => _index = 0)),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: _index != 1,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: screens),
          ),
          _FloatingTopBar(
            topInset: topInset,
            showSearch: _index == 0,
            solidBackground: _index == 2,
            onSearch: _openSearch,
          ),
        ],
      ),
      bottomNavigationBar: _LiquidGlassNavBar(
        selectedIndex: _index,
        onSelected: (v) => setState(() => _index = v),
      ),
    );
  }
}

class _FloatingTopBar extends StatelessWidget {
  final double topInset;
  final bool showSearch;
  final bool solidBackground;
  final VoidCallback onSearch;

  const _FloatingTopBar({
    required this.topInset,
    required this.showSearch,
    required this.solidBackground,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: topInset + _topBarHeight,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: solidBackground
                  ? background
                  : background.withValues(alpha: _chromeAlpha),
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: Container(
                  height: _topBarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: SizedBox(
                          height: double.infinity,
                          child: Transform.translate(
                            offset: const Offset(0, 2),
                            child: OverflowBox(
                              maxHeight: 72,
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/logo_0.PNG',
                                height: 72,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 52,
                          height: double.infinity,
                          child: Center(
                            child: showSearch
                                ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.78),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: scheme.outlineVariant.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: onSearch,
                                      iconSize: 22,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                      color: scheme.primary,
                                      icon: const Icon(Icons.search_rounded),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _LiquidGlassNavBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 46 + bottomInset,
          padding: EdgeInsets.fromLTRB(
            12,
            1,
            12,
            bottomInset > 0 ? bottomInset : 2,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: _chromeAlpha),
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.18),
              ),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, -6),
                color: scheme.shadow.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _LiquidNavItem(
                  icon: Icons.menu_book,
                  selectedIcon: Icons.menu_book,
                  label: "Меню",
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
              ),
              Expanded(
                child: _LiquidNavItem(
                  icon: Icons.shopping_cart_outlined,
                  selectedIcon: Icons.shopping_cart,
                  label: "Корзина",
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ),
              Expanded(
                child: _LiquidNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: "Профиль",
                  selected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LiquidNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 21,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSearchDelegate extends SearchDelegate<MenuItem?> {
  final List<MenuItem> items;

  _MenuSearchDelegate({required this.items});

  List<MenuItem> _filtered() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      final haystack = '${item.name} ${item.description}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  String get searchFieldLabel => 'Поиск напитков';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchList(
      items: _filtered(),
      onTap: (item) => close(context, item),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SearchList(
      items: _filtered(),
      onTap: (item) => close(context, item),
    );
  }
}

class _SearchList extends StatelessWidget {
  final List<MenuItem> items;
  final ValueChanged<MenuItem> onTap;

  const _SearchList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text("Ничего не найдено"));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final subtitle = item.description.trim();
        return ListTile(
          leading: Icon(
            item.category == MenuCategory.constructor
                ? Icons.auto_awesome
                : Icons.local_cafe,
          ),
          title: Text(item.name),
          subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1),
          trailing: Text(
            "${item.basePrice.toStringAsFixed(2)} BYN",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: () => onTap(item),
        );
      },
    );
  }
}
