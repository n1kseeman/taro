import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/cart.dart';
import '../models/promo_code.dart';
import '../ui/app_notice.dart';

String _formatMoney(double value) => "${value.toStringAsFixed(2)} BYN";

String _formatPromoValue(PromoCode promo) {
  final value = promo.discountValue % 1 == 0
      ? promo.discountValue.toStringAsFixed(0)
      : promo.discountValue.toStringAsFixed(2);
  return promo.discountType == PromoDiscountType.percent
      ? "$value%"
      : "$value BYN";
}

String _promoErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains("AUTH_REQUIRED")) {
    return "Войдите в аккаунт, чтобы использовать промокод";
  }
  if (message.contains("PROMO_EMPTY")) {
    return "Введите промокод";
  }
  if (message.contains("PROMO_NOT_FOUND")) {
    return "Промокод не найден";
  }
  if (message.contains("PROMO_INACTIVE")) {
    return "Этот промокод больше не активен";
  }
  if (message.contains("PROMO_ALREADY_USED")) {
    return "Этот аккаунт уже использовал данный промокод";
  }
  if (message.contains("PROMO_LIMIT_REACHED")) {
    return "Лимит использований этого промокода исчерпан";
  }
  if (message.contains("ORDERING_CLOSED")) {
    return "Оформление доступно с 12:00 до 21:50";
  }
  if (message.contains("INVALID_PICKUP_TIME")) {
    return "Выберите время с 12:10 до 21:50";
  }
  return "Ошибка: $error";
}

class CartScreen extends StatelessWidget {
  final VoidCallback? onOpenMenu;

  const CartScreen({super.key, this.onOpenMenu});

  static const double _bottomNavClearance = 84;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cart = s.cart;
    final topInset = MediaQuery.of(context).padding.top;
    const topBarClearance = 74.0;

    if (cart == null || cart.linesByKey.isEmpty) {
      return _EmptyCartState(
        onOpenMenu: onOpenMenu,
        topPadding: topInset + topBarClearance,
      );
    }

    final lines = cart.linesByKey.values.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              12,
              topInset + topBarClearance,
              12,
              _bottomNavClearance + 12,
            ),
            itemCount: lines.length,
            itemBuilder: (_, i) => _CartLineTile(line: lines[i]),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 4, 12, _bottomNavClearance),
          child: Column(
            children: [
              const _PromoCodeEntryButton(),
              const SizedBox(height: 6),
              _SummaryLine(label: "Сумма", value: _formatMoney(s.cartTotal)),
              const SizedBox(height: 2),
              SizedBox(
                height: 20,
                child: s.appliedPromo == null
                    ? const SizedBox.shrink()
                    : _SummaryLine(
                        label: "Скидка (${s.appliedPromo!.code})",
                        value:
                            "-${s.cartDiscountAmount.toStringAsFixed(2)} BYN",
                      ),
              ),
              const SizedBox(height: 2),
              _SummaryLine(
                label: "Итого",
                value: _formatMoney(s.cartTotalAfterDiscount),
                emphasize: true,
                oldValue: s.appliedPromo == null
                    ? null
                    : _formatMoney(s.cartTotal),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final s = context.read<AppState>();
                    if (!s.isAuthed) {
                      showAppNotice(
                        context,
                        "Сначала войдите в аккаунт",
                        isError: true,
                      );
                      return;
                    }
                    if (!s.isOrderingOpen()) {
                      showAppNotice(
                        context,
                        "Оформление доступно с 12:00 до 21:50",
                        isError: true,
                      );
                      return;
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PickupTimeScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Оформить заказ"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final String? oldValue;

  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.oldValue,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;
    final valueStyle = oldValue != null && emphasize
        ? titleStyle?.copyWith(color: scheme.primary)
        : titleStyle;
    final oldValueStyle =
        (emphasize
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationThickness: 2,
            );

    return Row(
      children: [
        Expanded(child: Text(label, style: titleStyle)),
        if (oldValue != null) ...[
          Text(oldValue!, style: oldValueStyle),
          const SizedBox(width: 8),
        ],
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  final VoidCallback? onOpenMenu;
  final double topPadding;

  const _EmptyCartState({this.onOpenMenu, required this.topPadding});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, topPadding, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 46,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Ваша корзина пуста",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              "Загляните в меню и наполните её прямо сейчас любимыми блюдами!",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenMenu,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? scheme.primaryContainer
                      : scheme.primary,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? scheme.onPrimaryContainer
                      : scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text("Перейти в меню"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final item = s.findMenuItemById(line.menuItemId);
    if (item == null) {
      return const SizedBox.shrink();
    }

    String sizeLabel = "";
    if (line.sizeId != null) {
      final found = item.sizes.where((x) => x.id == line.sizeId).toList();
      if (found.isNotEmpty) sizeLabel = found.first.displayLabel;
    }

    final addonsSource = s.addonsForItem(item);
    final addonNames = addonsSource
        .where((a) => line.addonIds.contains(a.id))
        .map((a) => a.name)
        .toList();
    final attachedAddonNames = line.attachedAddons
        .map((attached) {
          final addonItem = s.findMenuItemById(attached.menuItemId);
          if (addonItem == null) return null;
          return "${addonItem.name} x${attached.qty}";
        })
        .whereType<String>()
        .toList();

    final subtitleParts = <String>[];
    if (item.id == "builder_custom") {
      final customParts = <String>[];
      if (sizeLabel.isNotEmpty) customParts.add(sizeLabel);
      customParts.addAll(addonNames);
      if (customParts.isNotEmpty) {
        subtitleParts.add(customParts.join(" / "));
      }
    } else {
      if (sizeLabel.isNotEmpty) subtitleParts.add(sizeLabel);
      if (addonNames.isNotEmpty) {
        subtitleParts.add("Добавки: ${addonNames.join(", ")}");
      }
      if (attachedAddonNames.isNotEmpty) {
        subtitleParts.add("Допы: ${attachedAddonNames.join(", ")}");
      }
    }
    final lineTotal = s.lineTotal(line);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(item.name),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text(subtitleParts.join(" • ")),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => s.changeQty(line.key, -1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  "${line.qty}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () => s.changeQty(line.key, 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
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
        ),
      ),
    );
  }
}

class _PromoCodeEntryButton extends StatelessWidget {
  const _PromoCodeEntryButton();

  static const double _promoStatusSlotHeight = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appliedPromo = context.watch<AppState>().appliedPromo;

    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () => _showPromoCodeDialog(
              context,
              initialCode: appliedPromo?.code ?? "",
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: scheme.primary,
            ),
            child: Text(
              "Ввести промокод",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationThickness: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _promoStatusSlotHeight,
            child: appliedPromo == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Icon(
                        Icons.discount_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Применён ${appliedPromo.code} • ${_formatPromoValue(appliedPromo)}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            context.read<AppState>().removeAppliedPromo(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("Убрать"),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPromoCodeDialog(
    BuildContext context, {
    required String initialCode,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Промокод',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          _PromoCodeDialog(initialCode: initialCode),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}

class _PromoCodeDialog extends StatefulWidget {
  final String initialCode;

  const _PromoCodeDialog({required this.initialCode});

  @override
  State<_PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<_PromoCodeDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appliedPromo = context.read<AppState>().appliedPromo;
    final navigator = Navigator.of(context, rootNavigator: true);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: scheme.shadow.withValues(alpha: 0.14),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Промокод",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: "Введите промокод",
                          isDense: true,
                        ),
                        onTapOutside: (_) => _focusNode.unfocus(),
                        onChanged: (_) {
                          if (_errorText == null) return;
                          setState(() => _errorText = null);
                        },
                        onSubmitted: (_) => _applyPromoCode(context, navigator),
                      ),
                      SizedBox(
                        height: 18,
                        child: _errorText == null
                            ? null
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _errorText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (appliedPromo != null)
                            TextButton(
                              onPressed: () {
                                _focusNode.unfocus();
                                context.read<AppState>().removeAppliedPromo();
                                navigator.pop();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Text("Убрать"),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _focusNode.unfocus();
                              navigator.pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: const Text("Отмена"),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () =>
                                _applyPromoCode(context, navigator),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: const Text("Применить"),
                          ),
                        ],
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

  void _applyPromoCode(BuildContext context, NavigatorState navigator) {
    try {
      _focusNode.unfocus();
      context.read<AppState>().applyPromoCode(_controller.text);
      navigator.pop();
    } catch (error) {
      setState(() => _errorText = _promoErrorMessage(error));
    }
  }
}

// --------- Pickup time screen (step 10 min + comment + working hours) ---------

class PickupTimeScreen extends StatefulWidget {
  const PickupTimeScreen({super.key});

  @override
  State<PickupTimeScreen> createState() => _PickupTimeScreenState();
}

class _PickupTimeScreenState extends State<PickupTimeScreen> {
  DateTime? _selected;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  List<DateTime> _buildSlots() {
    final s = context.read<AppState>();
    final now = DateTime.now();
    if (!s.isOrderingOpen(now)) return const [];

    DateTime roundUp10(DateTime t) {
      final add = (10 - (t.minute % 10)) % 10;
      final r = t.add(Duration(minutes: add));
      return DateTime(r.year, r.month, r.day, r.hour, r.minute);
    }

    final start = roundUp10(now).isBefore(s.firstPickupTimeFor(now))
        ? s.firstPickupTimeFor(now)
        : roundUp10(now);
    final close = s.orderCloseTimeFor(now);

    final slots = <DateTime>[];
    var t = start;
    while (t.isBefore(close) || t.isAtSameMomentAs(close)) {
      slots.add(t);
      t = t.add(const Duration(minutes: 10));
    }
    return slots;
  }

  String _fmt(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.hour)}:${two(t.minute)}";
  }

  Future<void> _pickPlatformTime(List<DateTime> slots) async {
    if (slots.isEmpty) return;
    if (Platform.isIOS || Platform.isMacOS) {
      var temp = _selected ?? slots.first;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          return Container(
            height: 320,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Отмена"),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        onPressed: () {
                          setState(() => _selected = temp);
                          Navigator.pop(context);
                        },
                        child: const Text("Готово"),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    minuteInterval: 10,
                    initialDateTime: temp,
                    minimumDate: slots.first,
                    maximumDate: slots.last,
                    onDateTimeChanged: (value) => temp = value,
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selected ?? slots.first),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    if (!mounted) return;
    final now = DateTime.now();
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
    final found = slots.where((slot) => slot == candidate).toList();
    if (found.isEmpty) {
      showAppNotice(
        context,
        "Выберите время с шагом 10 минут в диапазоне 12:10–21:50",
        isError: true,
      );
      return;
    }
    setState(() => _selected = found.first);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final slots = _buildSlots();
    final appliedPromo = s.appliedPromo;

    if (slots.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Время самовывоза")),
        body: const Center(child: Text("Оформление доступно с 12:00 до 21:50")),
      );
    }

    _selected ??= slots.first;

    return Scaffold(
      appBar: AppBar(title: const Text("Время самовывоза")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Выберите время",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Самовывоз доступен с 12:10 до 21:50",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _pickPlatformTime(slots),
                      child: Text(_fmt(_selected!)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Комментарий к заказу",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Сумма заказа",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryLine(
                    label: "Сумма",
                    value: _formatMoney(s.cartTotal),
                  ),
                  if (appliedPromo != null) ...[
                    const SizedBox(height: 8),
                    _SummaryLine(
                      label: "Скидка (${appliedPromo.code})",
                      value: "-${s.cartDiscountAmount.toStringAsFixed(2)} BYN",
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SummaryLine(
                    label: "Итого",
                    value: _formatMoney(s.cartTotalAfterDiscount),
                    emphasize: true,
                    oldValue: appliedPromo == null
                        ? null
                        : _formatMoney(s.cartTotal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    if (!s.isOrderingOpen()) {
                      showAppNotice(
                        context,
                        "Оформление доступно с 12:00 до 21:50",
                        isError: true,
                      );
                      return;
                    }
                    await s.checkout(
                      pickupTime: _selected!,
                      comment: _comment.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showAppNotice(context, "Заказ оформлен");
                  } catch (e) {
                    if (!context.mounted) return;
                    showAppNotice(
                      context,
                      _promoErrorMessage(e),
                      isError: true,
                    );
                  }
                },
                child: const Text("Подтвердить"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
