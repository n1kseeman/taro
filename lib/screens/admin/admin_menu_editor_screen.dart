import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/menu.dart';
import '../../models/promo_code.dart';
import '../../ui/app_notice.dart';
import '../main_navigation_screen.dart';
import 'admin_orders_screen.dart';

enum _SaveState { idle, saving, saved, error }

class AdminMenuEditorScreen extends StatefulWidget {
  const AdminMenuEditorScreen({super.key});

  @override
  State<AdminMenuEditorScreen> createState() => _AdminMenuEditorScreenState();
}

class _AdminMenuEditorScreenState extends State<AdminMenuEditorScreen>
    with SingleTickerProviderStateMixin {
  late List<MenuItem> _items;
  late List<MenuAddon> _addons;
  late List<PromoCode> _promoCodes;

  late final TabController _tab;
  bool _isSaving = false;
  bool _saveQueued = false;
  _SaveState _saveState = _SaveState.idle;

  @override
  void initState() {
    super.initState();

    final s = context.read<AppState>();
    _items = List<MenuItem>.from(s.menu);
    _addons = List<MenuAddon>.from(s.globalAddons);
    _promoCodes = List<PromoCode>.from(s.promoCodes);

    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _saveAll(AppState s) async {
    if (_isSaving) {
      _saveQueued = true;
      return;
    }

    setState(() {
      _isSaving = true;
      _saveState = _SaveState.saving;
    });
    try {
      await s.saveMenuConfiguration(
        menuItems: _items,
        globalAddons: _addons,
        promoCodes: _promoCodes,
      );
      if (!mounted) return;
      setState(() => _saveState = _SaveState.saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveState = _SaveState.error);
      showAppNotice(
        context,
        "Не удалось сохранить изменения в облако",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      } else {
        _isSaving = false;
      }
      if (_saveQueued && mounted) {
        _saveQueued = false;
        Future.microtask(() => _saveAll(s));
      }
    }
  }

  Future<void> _applyAndSave(
    AppState s,
    VoidCallback mutation,
  ) async {
    setState(mutation);
    await _saveAll(s);
  }

  String _fmtNutrition(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
  }

  String _fmtPromoValue(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String get _imagePickerButtonLabel =>
      Theme.of(context).platform == TargetPlatform.macOS
      ? "Выбрать из Finder"
      : "Выбрать из галереи";

  Widget _buildSaveStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (_saveState) {
      _SaveState.saving => (
        Icons.cloud_upload_outlined,
        "Сохраняется...",
        scheme.primary,
      ),
      _SaveState.saved => (
        Icons.cloud_done_outlined,
        "Сохранено",
        const Color(0xFF2E7D32),
      ),
      _SaveState.error => (
        Icons.cloud_off_outlined,
        "Ошибка",
        scheme.error,
      ),
      _SaveState.idle => (
        Icons.edit_note_outlined,
        "Готово",
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppState s) {
    final cafe = s.selectedCafe;
    return AppBar(
      title: Text("Админ • ${cafe.name}"),
      bottom: TabBar(
        controller: _tab,
        tabs: const [
          Tab(text: "Заказы"),
          Tab(text: "Меню"),
          Tab(text: "Промокоды"),
        ],
      ),
      actions: [
        Center(child: _buildSaveStatus(context)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FilledButton.tonalIcon(
            onPressed: _isSaving
                ? null
                : () async {
              await _saveAll(s);
              if (!mounted) return;
            },
            icon: Icon(
              _isSaving ? Icons.sync_rounded : Icons.save_outlined,
            ),
            label: Text(_isSaving ? "Сохраняем" : "Сохранить"),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            s.adminLogout();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const MainNavigationScreen(initialIndex: 2),
              ),
              (_) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final background = Theme.of(context).scaffoldBackgroundColor;

    if (!s.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("Админ")),
        body: const Center(child: Text("Нет доступа")),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(s),

      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (context, child) {
          if (_tab.index == 1) {
            return FloatingActionButton(
              onPressed: () async {
                final created = await _editItemDialog(context);
                if (created != null) {
                  await _applyAndSave(
                    s,
                    () => _items.add(created),
                  );
                }
              },
              child: const Icon(Icons.add),
            );
          }

          if (_tab.index == 2) {
            return FloatingActionButton(
              onPressed: () async {
                final created = await _editPromoDialog(context);
                if (created != null) {
                  await _applyAndSave(
                    s,
                    () => _promoCodes.add(created),
                  );
                }
              },
              child: const Icon(Icons.add_card_outlined),
            );
          }

          return const SizedBox.shrink();
        },
      ),

      body: TabBarView(
        controller: _tab,
        children: [
          const AdminOrdersScreen(),

          Container(
            color: background,
            child: _AdminMenuList(
              items: _items,
              onEdit: (index) async {
                final updated = await _editItemDialog(
                  context,
                  existing: _items[index],
                );
                if (updated != null) {
                  await _applyAndSave(
                    s,
                    () => _items[index] = updated,
                  );
                }
              },
              onDelete: (index) async {
                await _applyAndSave(
                  s,
                  () => _items.removeAt(index),
                );
              },
              onToggleHidden: (index, hidden) async {
                await _applyAndSave(s, () {
                  final it = _items[index];
                  _items[index] = MenuItem(
                    id: it.id,
                    category: it.category,
                    name: it.name,
                    basePrice: it.basePrice,
                    description: it.description,
                    nutrition: it.nutrition,
                    sizes: it.sizes,
                    addons: it.addons,
                    showNutrition: it.showNutrition,
                    imageUrl: it.imageUrl,
                    isHidden: hidden,
                    isTop: it.isTop,
                  );
                });
              },
            ),
          ),

          Container(
            color: background,
            child: _AdminPromoCodesList(
              promoCodes: _promoCodes,
              onEdit: (index) async {
                final updated = await _editPromoDialog(
                  context,
                  existing: _promoCodes[index],
                );
                if (updated != null) {
                  await _applyAndSave(
                    s,
                    () => _promoCodes[index] = updated,
                  );
                }
              },
              onDelete: (index) async {
                await _applyAndSave(
                  s,
                  () => _promoCodes.removeAt(index),
                );
              },
              onToggleActive: (index, isActive) async {
                await _applyAndSave(s, () {
                  _promoCodes[index] = _promoCodes[index].copyWith(
                    isActive: isActive,
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Menu item dialog ----------------

  Future<MenuItem?> _editItemDialog(
    BuildContext context, {
    MenuItem? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? "");
    final price = TextEditingController(
      text: existing?.basePrice.toStringAsFixed(2) ?? "0.00",
    );
    final desc = TextEditingController(text: existing?.description ?? "");
    final img = TextEditingController(text: existing?.imageUrl ?? "");

    final kcal = TextEditingController(
      text: existing == null ? "0" : _fmtNutrition(existing.nutrition.kcal),
    );
    final p = TextEditingController(
      text: existing?.nutrition.protein.toString() ?? "0",
    );
    final f = TextEditingController(
      text: existing?.nutrition.fat.toString() ?? "0",
    );
    final c = TextEditingController(
      text: existing?.nutrition.carbs.toString() ?? "0",
    );

    MenuCategory cat = existing?.category ?? MenuCategory.milkBase;
    final sizes = List<MenuSize>.from(existing?.sizes ?? const []);
    final addons = List<MenuAddon>.from(existing?.addons ?? const []);
    var showNutrition = existing?.showNutrition ?? true;
    var isTop = existing?.isTop ?? false;

    final result = await showDialog<MenuItem>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            return AlertDialog(
              title: Text(existing == null ? "Новая позиция" : "Редактировать"),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<MenuCategory>(
                        initialValue: cat,
                        items: const [
                          DropdownMenuItem(
                            value: MenuCategory.constructor,
                            child: Text("Конструктор"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.milkBase,
                            child: Text("Milk Base"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.fruitCream,
                            child: Text("Fruit&Cream"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.bubbleCoffee,
                            child: Text("Bubble coffee"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.matcha,
                            child: Text("Matcha"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.fruitTea,
                            child: Text("Fruit&Tea"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.coffee,
                            child: Text("Кофе"),
                          ),
                          DropdownMenuItem(
                            value: MenuCategory.addons,
                            child: Text("Добавки"),
                          ),
                        ],
                        onChanged: (v) => setLocalState(
                          () => cat = v ?? MenuCategory.milkBase,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: "Название",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: price,
                        decoration: const InputDecoration(
                          labelText: "Цена (BYN)",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: img,
                        decoration: const InputDecoration(
                          labelText: "Фото (URL или data:image)",
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final dataUri = await _pickImageAsDataUri();
                            if (dataUri == null) return;
                            setLocalState(() => img.text = dataUri);
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_imagePickerButtonLabel),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: desc,
                        decoration: const InputDecoration(
                          labelText: "Описание / состав",
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isTop,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Показывать бейдж ТОП"),
                        onChanged: (value) =>
                            setLocalState(() => isTop = value),
                      ),
                      SwitchListTile.adaptive(
                        value: showNutrition,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Показывать КБЖУ в карточке товара"),
                        onChanged: (value) =>
                            setLocalState(() => showNutrition = value),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("КБЖУ"),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: kcal,
                              decoration: const InputDecoration(
                                labelText: "Ккал",
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: p,
                              decoration: const InputDecoration(labelText: "Б"),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: f,
                              decoration: const InputDecoration(labelText: "Ж"),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: c,
                              decoration: const InputDecoration(labelText: "У"),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Размеры",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final created = await _editSizeDialog(dialogCtx);
                              if (created == null) return;
                              setLocalState(() => sizes.add(created));
                            },
                            icon: const Icon(Icons.add),
                            label: const Text("Добавить"),
                          ),
                        ],
                      ),
                      if (sizes.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Размеров нет"),
                        ),
                      ...sizes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final sz = entry.value;
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          title: Text(sz.displayLabel),
                          subtitle: Text(
                            "ID: ${sz.id} • +${sz.priceDelta.toStringAsFixed(2)} BYN",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () async {
                                  final updated = await _editSizeDialog(
                                    dialogCtx,
                                    existing: sz,
                                  );
                                  if (updated == null) return;
                                  setLocalState(() => sizes[index] = updated);
                                },
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setLocalState(() => sizes.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (cat == MenuCategory.constructor) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Добавки конструктора",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final created = await _editAddonDialog(
                                  dialogCtx,
                                );
                                if (created == null) return;
                                setLocalState(() => addons.add(created));
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Добавить"),
                            ),
                          ],
                        ),
                        if (addons.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Добавок пока нет"),
                          ),
                        ...addons.asMap().entries.map((entry) {
                          final index = entry.key;
                          final addon = entry.value;
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            leading: addon.imageUrl.trim().isEmpty
                                ? const CircleAvatar(
                                    child: Icon(Icons.image_outlined, size: 18),
                                  )
                                : CircleAvatar(
                                    backgroundImage: _imageProvider(
                                      addon.imageUrl,
                                    ),
                                    child:
                                        _imageProvider(addon.imageUrl) == null
                                        ? const Icon(
                                            Icons.broken_image_outlined,
                                            size: 18,
                                          )
                                        : null,
                                  ),
                            title: Text(addon.name),
                            subtitle: Text(
                              "ID: ${addon.id} • +${addon.price.toStringAsFixed(2)} BYN",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () async {
                                    final updated = await _editAddonDialog(
                                      dialogCtx,
                                      existing: addon,
                                    );
                                    if (updated == null) return;
                                    setLocalState(
                                      () => addons[index] = updated,
                                    );
                                  },
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => setLocalState(
                                    () => addons.removeAt(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: () {
                    final pr =
                        double.tryParse(price.text.replaceAll(",", ".")) ?? 0;

                    final nutrition = Nutrition(
                      kcal:
                          double.tryParse(kcal.text.replaceAll(",", ".")) ?? 0,
                      protein:
                          double.tryParse(p.text.replaceAll(",", ".")) ?? 0,
                      fat: double.tryParse(f.text.replaceAll(",", ".")) ?? 0,
                      carbs: double.tryParse(c.text.replaceAll(",", ".")) ?? 0,
                    );

                    final id = existing?.id ?? "m${Random().nextInt(999999)}";

                    Navigator.pop(
                      dialogCtx,
                      MenuItem(
                        id: id,
                        category: cat,
                        name: name.text.trim(),
                        basePrice: pr,
                        description: desc.text.trim(),
                        nutrition: nutrition,
                        sizes: sizes,
                        addons: addons,
                        showNutrition: showNutrition,
                        imageUrl: img.text.trim(),
                        isHidden: existing?.isHidden ?? false,
                        isTop: isTop,
                      ),
                    );
                  },
                  child: const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );

    // ✅ ВАЖНО: НЕ dispose() здесь — иначе iPad может крашнуться на анимации закрытия.
    return result;
  }

  Future<MenuSize?> _editSizeDialog(
    BuildContext context, {
    MenuSize? existing,
  }) async {
    final label = TextEditingController(text: existing?.label ?? "");
    final volume = TextEditingController(
      text: existing?.volumeMl?.toString() ?? "",
    );
    final price = TextEditingController(
      text: existing?.priceDelta.toStringAsFixed(2) ?? "0.00",
    );
    final id = TextEditingController(text: existing?.id ?? "");

    final result = await showDialog<MenuSize>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            existing == null ? "Новый размер" : "Редактировать размер",
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: "Название размера (например M, L)",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: volume,
                    decoration: const InputDecoration(labelText: "Объём (мл)"),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    decoration: const InputDecoration(
                      labelText: "Доплата (BYN)",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: id,
                    decoration: const InputDecoration(
                      labelText: "ID (если пусто — создадим автоматически)",
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () {
                final delta =
                    double.tryParse(price.text.replaceAll(",", ".")) ?? 0.0;
                final parsedVolume = int.tryParse(volume.text.trim());
                final finalId = id.text.trim().isEmpty
                    ? "s${Random().nextInt(999999)}"
                    : id.text.trim();

                Navigator.pop(
                  dialogCtx,
                  MenuSize(
                    id: finalId,
                    label: label.text.trim(),
                    volumeMl: parsedVolume,
                    priceDelta: delta,
                  ),
                );
              },
              child: const Text("Сохранить"),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<MenuAddon?> _editAddonDialog(
    BuildContext context, {
    MenuAddon? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? "");
    final price = TextEditingController(
      text: existing?.price.toStringAsFixed(2) ?? "0.00",
    );
    final id = TextEditingController(text: existing?.id ?? "");
    final image = TextEditingController(text: existing?.imageUrl ?? "");

    final result = await showDialog<MenuAddon>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            return AlertDialog(
              title: Text(
                existing == null ? "Новая добавка" : "Редактировать добавку",
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: "Название",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: price,
                        decoration: const InputDecoration(
                          labelText: "Цена (BYN)",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: id,
                        decoration: const InputDecoration(
                          labelText: "ID (если пусто — создадим автоматически)",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: image,
                        decoration: const InputDecoration(
                          labelText: "Фото (URL или data:image)",
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final dataUri = await _pickImageAsDataUri();
                            if (dataUri == null) return;
                            setLocalState(() => image.text = dataUri);
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_imagePickerButtonLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: () {
                    final finalId = id.text.trim().isEmpty
                        ? "a${Random().nextInt(999999)}"
                        : id.text.trim();
                    Navigator.pop(
                      dialogCtx,
                      MenuAddon(
                        id: finalId,
                        name: name.text.trim(),
                        price:
                            double.tryParse(price.text.replaceAll(",", ".")) ??
                            0,
                        imageUrl: image.text.trim(),
                      ),
                    );
                  },
                  child: const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<PromoCode?> _editPromoDialog(
    BuildContext context, {
    PromoCode? existing,
  }) async {
    final code = TextEditingController(text: existing?.code ?? "");
    final discountValue = TextEditingController(
      text: existing == null ? "" : _fmtPromoValue(existing.discountValue),
    );
    final maxUses = TextEditingController(
      text: existing?.maxUses?.toString() ?? "",
    );

    var discountType = existing?.discountType ?? PromoDiscountType.fixedAmount;
    var isActive = existing?.isActive ?? true;

    final result = await showDialog<PromoCode>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            return AlertDialog(
              title: Text(
                existing == null ? "Новый промокод" : "Редактировать промокод",
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: "Промокод",
                          hintText: "Например TAPO10",
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<PromoDiscountType>(
                        initialValue: discountType,
                        decoration: const InputDecoration(
                          labelText: "Тип скидки",
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PromoDiscountType.fixedAmount,
                            child: Text("Фиксированная сумма"),
                          ),
                          DropdownMenuItem(
                            value: PromoDiscountType.percent,
                            child: Text("Проценты"),
                          ),
                        ],
                        onChanged: (value) => setLocalState(
                          () => discountType =
                              value ?? PromoDiscountType.fixedAmount,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountValue,
                        decoration: InputDecoration(
                          labelText: discountType == PromoDiscountType.percent
                              ? "Скидка (%)"
                              : "Скидка (BYN)",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: maxUses,
                        decoration: const InputDecoration(
                          labelText: "Общее количество использований",
                          helperText: "Оставьте пустым, если лимита нет",
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      if (existing != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          existing.maxUses == null
                              ? "Использован ${existing.usesCount} раз"
                              : "Использован ${existing.usesCount} из ${existing.maxUses}",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isActive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Промокод активен"),
                        subtitle: const Text(
                          "Один аккаунт может использовать код только один раз",
                        ),
                        onChanged: (value) =>
                            setLocalState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: () {
                    final normalizedCode = normalizePromoCode(code.text);
                    if (normalizedCode.isEmpty) {
                      showAppNotice(context, "Введите промокод", isError: true);
                      return;
                    }

                    final duplicateExists = _promoCodes.any(
                      (promo) =>
                          promo.id != existing?.id &&
                          promo.code == normalizedCode,
                    );
                    if (duplicateExists) {
                      showAppNotice(
                        context,
                        "Промокод с таким названием уже существует",
                        isError: true,
                      );
                      return;
                    }

                    final parsedDiscount = double.tryParse(
                      discountValue.text.replaceAll(",", "."),
                    );
                    if (parsedDiscount == null || parsedDiscount <= 0) {
                      showAppNotice(
                        context,
                        "Введите корректную скидку",
                        isError: true,
                      );
                      return;
                    }
                    if (discountType == PromoDiscountType.percent &&
                        parsedDiscount > 100) {
                      showAppNotice(
                        context,
                        "Процент скидки не может быть больше 100",
                        isError: true,
                      );
                      return;
                    }

                    final rawMaxUses = maxUses.text.trim();
                    final parsedMaxUses = rawMaxUses.isEmpty
                        ? null
                        : int.tryParse(rawMaxUses);
                    if (rawMaxUses.isNotEmpty &&
                        (parsedMaxUses == null || parsedMaxUses <= 0)) {
                      showAppNotice(
                        context,
                        "Лимит использований должен быть больше нуля",
                        isError: true,
                      );
                      return;
                    }
                    if (existing != null &&
                        parsedMaxUses != null &&
                        parsedMaxUses < existing.usesCount) {
                      showAppNotice(
                        context,
                        "Лимит не может быть меньше уже использованного количества",
                        isError: true,
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogCtx,
                      PromoCode(
                        id: existing?.id ?? "promo_${Random().nextInt(999999)}",
                        code: normalizedCode,
                        discountType: discountType,
                        discountValue: parsedDiscount,
                        maxUses: parsedMaxUses,
                        usedByUserIds: existing?.usedByUserIds ?? const [],
                        isActive: isActive,
                        createdAt: existing?.createdAt ?? DateTime.now(),
                      ),
                    );
                  },
                  child: const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<String?> _pickImageAsDataUri() async {
    final bytesAndMime = await _pickImageBytesAndMime();
    if (bytesAndMime == null) return null;
    final bytes = bytesAndMime.bytes;
    final mime = bytesAndMime.mimeType;
    return "data:$mime;base64,${base64Encode(bytes)}";
  }

  Future<({Uint8List bytes, String mimeType})?> _pickImageBytesAndMime() async {
    if (Theme.of(context).platform == TargetPlatform.macOS) {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'images',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
          ),
        ],
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? _mimeFromName(file.name);
      return (bytes: bytes, mimeType: mime);
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? _mimeFromName(picked.name);
    return (bytes: bytes, mimeType: mime);
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  ImageProvider<Object>? _imageProvider(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith("data:image")) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(base64Decode(trimmed.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(trimmed);
  }
}

class _AdminMenuList extends StatelessWidget {
  final List<MenuItem> items;
  final Future<void> Function(int index) onEdit;
  final void Function(int index) onDelete;
  final void Function(int index, bool hidden) onToggleHidden;

  const _AdminMenuList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
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
          child: const Text("Меню пустое"),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final scheme = Theme.of(context).colorScheme;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        it.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: it.isHidden,
                      onChanged: (v) => onToggleHidden(i, v),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${menuCategoryTitle(it.category)} • ${it.basePrice.toStringAsFixed(2)} BYN",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (it.isTop)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "ТОП",
                      style: TextStyle(
                        color: Color(0xFF3BA55D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (it.sizes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Размеры: ${it.sizes.map((s) => s.displayLabel).join(", ")}",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (!it.showNutrition)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "КБЖУ скрыто",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (it.isHidden)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "СКРЫТ ИЗ МЕНЮ",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onEdit(i),
                      icon: const Icon(Icons.edit),
                      label: const Text("Редактировать"),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onDelete(i),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Удалить"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminPromoCodesList extends StatelessWidget {
  final List<PromoCode> promoCodes;
  final Future<void> Function(int index) onEdit;
  final void Function(int index) onDelete;
  final void Function(int index, bool isActive) onToggleActive;

  const _AdminPromoCodesList({
    required this.promoCodes,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  String _discountLabel(PromoCode promo) {
    final value = promo.discountValue % 1 == 0
        ? promo.discountValue.toStringAsFixed(0)
        : promo.discountValue.toStringAsFixed(2);
    return promo.discountType == PromoDiscountType.percent
        ? "-$value%"
        : "-$value BYN";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (promoCodes.isEmpty) {
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
          child: const Text("Промокодов пока нет"),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: promoCodes.length,
      itemBuilder: (_, i) {
        final promo = promoCodes[i];
        final statusColor = promo.isExhausted
            ? Colors.orange
            : promo.isActive
            ? const Color(0xFF2E7D32)
            : scheme.onSurfaceVariant;
        final statusText = promo.isExhausted
            ? "Лимит исчерпан"
            : promo.isActive
            ? "Активен"
            : "Отключён";
        final usageText = promo.maxUses == null
            ? "Использований: ${promo.usesCount} / без лимита"
            : "Использований: ${promo.usesCount}/${promo.maxUses}";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        promo.code,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Switch(
                      value: promo.isActive,
                      onChanged: (value) => onToggleActive(i, value),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _discountLabel(promo),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  usageText,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  "Один аккаунт не сможет использовать этот код повторно",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onEdit(i),
                      icon: const Icon(Icons.edit),
                      label: const Text("Редактировать"),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onDelete(i),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Удалить"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
