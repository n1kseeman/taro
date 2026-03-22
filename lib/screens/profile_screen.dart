import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../ui/app_notice.dart';
import 'auth_screen.dart';
import 'favorites_screen.dart';
import 'order_details_screen.dart';
import 'order_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    if (!s.isAuthed) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: EdgeInsets.fromLTRB(12, topInset + 62, 12, 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.82)
                : scheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.28 : 0.18,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Кто вы?",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Войдите, для быстрого оформления заказа и получения бонусов!",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? scheme.primaryContainer
                        : scheme.primary,
                    foregroundColor: isDark
                        ? scheme.onPrimaryContainer
                        : scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text("Войти или зарегистрироваться"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final user = s.currentUser!;

    return ListView(
      padding: EdgeInsets.fromLTRB(12, topInset + 62, 12, 110),
      children: [
        _AccountCard(user: user),
        if (!user.notificationsEnabled) ...[
          const SizedBox(height: 10),
          _NotificationCard(
            enabled: user.notificationsEnabled,
            onChanged: (value) =>
                context.read<AppState>().setNotificationsEnabled(value),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),
        ..._activeOrdersBlock(context, s),
        if (s.activeOrdersForCurrentUserSelectedCafe.isNotEmpty)
          const SizedBox(height: 12),
        _ProfileActionGroup(
          children: [
            _ProfileActionTile(
              title: "Любимые",
              icon: Icons.favorite_border,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
            ),
            _ProfileActionTile(
              title: "История заказов",
              icon: Icons.receipt_long_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                );
              },
            ),
            _ProfileActionTile(
              title: "Темная тема",
              icon: Icons.dark_mode_outlined,
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _ThemeModeSheet(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileActionGroup(
          children: [
            _ProfileActionTile(
              title: "О нас",
              icon: Icons.info_outline,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileActionGroup(
          children: [
            _ProfileActionTile(
              title: "Выйти",
              icon: Icons.logout,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Выйти из аккаунта?"),
                    content: const Text("Вы уверены?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Отмена"),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Выйти"),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await context.read<AppState>().logout();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _activeOrdersBlock(BuildContext context, AppState s) {
    final list = s.activeOrdersForCurrentUserSelectedCafe;
    if (list.isEmpty) {
      return const [];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          "Активные заказы",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      ...list.map((o) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              title: Text("Заказ #${o.id.substring(0, 6)}"),
              subtitle: Text(
                "${s.cafe.name} • Самовывоз: ${_fmt(o.pickupTime)}",
              ),
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
          ),
        );
      }),
    ];
  }

  static String _fmt(DateTime t) {
    String two(int x) => x.toString().padLeft(2, "0");
    return "${two(t.hour)}:${two(t.minute)}";
  }
}

class _AccountCard extends StatelessWidget {
  final AppUser user;

  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileAvatar(user: user, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  user.phone.trim().isEmpty ? "Номер не указан" : user.phone,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Уведомления",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  enabled
                      ? "Уведомления активны. Будем сообщать о статусе заказа и важных обновлениях."
                      : "Включите уведомления, чтобы вовремя видеть статус заказа и важные обновления.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ThemeModeSheet extends StatelessWidget {
  const _ThemeModeSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = context.watch<AppState>().themeMode;

    Widget option({
      required String title,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.95)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.65)
                    : scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.32,
      maxChildSize: 0.56,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: scheme.surface,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Темная тема",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Выберите режим оформления приложения.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    option(
                      title: "Светлая",
                      selected: mode == ThemeMode.light,
                      onTap: () => context.read<AppState>().setThemeMode(
                        ThemeMode.light,
                      ),
                    ),
                    const SizedBox(width: 10),
                    option(
                      title: "Тёмная",
                      selected: mode == ThemeMode.dark,
                      onTap: () =>
                          context.read<AppState>().setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        context.read<AppState>().setThemeMode(ThemeMode.system),
                    child: Text(
                      mode == ThemeMode.system
                          ? "Как на устройстве: включено"
                          : "Как на устройстве",
                    ),
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

class _ProfileActionGroup extends StatelessWidget {
  final List<_ProfileActionTile> children;

  const _ProfileActionGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(icon, size: 28, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late String? _gender;
  DateTime? _birthDate;
  String? _photoDataUri;

  bool get _birthDateLocked => widget.user.birthDate != null;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _phone = TextEditingController(text: _normalizePhone(widget.user.phone));
    _email = TextEditingController(text: widget.user.email);
    _gender = widget.user.gender;
    _birthDate = widget.user.birthDate;
    _photoDataUri = widget.user.photoDataUri;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final localDigits = digits.startsWith('375') ? digits.substring(3) : digits;
    return _BelarusPhoneFormatter.formatFromDigits(localDigits);
  }

  bool _isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final localDigits = digits.startsWith('375') ? digits.substring(3) : digits;
    return localDigits.length == 9;
  }

  Future<void> _pickProfilePhoto() async {
    final bytesAndMime = await _pickImageBytesAndMime();
    if (bytesAndMime == null) return;
    setState(() {
      _photoDataUri =
          "data:${bytesAndMime.mimeType};base64,${base64Encode(bytesAndMime.bytes)}";
    });
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
      return (
        bytes: bytes,
        mimeType: file.mimeType ?? _mimeFromName(file.name),
      );
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return (
      bytes: bytes,
      mimeType: picked.mimeType ?? _mimeFromName(picked.name),
    );
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Future<void> _pickBirthDate() async {
    if (_birthDateLocked) return;

    final initialDate = _birthDate ?? DateTime(DateTime.now().year - 18, 1, 1);
    final firstDate = DateTime(1950);
    final lastDate = DateTime.now();

    if (Platform.isIOS || Platform.isMacOS) {
      var temp = initialDate;
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
                          setState(() => _birthDate = temp);
                          Navigator.pop(context);
                        },
                        child: const Text("Готово"),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    dateOrder: DatePickerDateOrder.dmy,
                    maximumDate: lastDate,
                    minimumDate: firstDate,
                    initialDateTime: initialDate,
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

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ru'),
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Редактирование"),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Stack(
              children: [
                _EditableProfileAvatar(photoDataUri: _photoDataUri, size: 92),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    onPressed: _pickProfilePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Настройки аккаунта",
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            "Обновите основные данные профиля.",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          _EditFieldCard(
            label: "Имя",
            controller: _firstName,
            hintText: "Введите имя",
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _EditFieldCard(
            label: "Фамилия",
            controller: _lastName,
            hintText: "Введите фамилию",
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _EditFieldCard(
            label: "Телефон",
            controller: _phone,
            hintText: "+375 XX XXX-XX-XX",
            keyboardType: TextInputType.phone,
            isDark: isDark,
            inputFormatters: [_BelarusPhoneFormatter()],
          ),
          const SizedBox(height: 12),
          _GenderFieldCard(
            value: _gender,
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 12),
          _DateFieldCard(
            value: _birthDate == null ? null : _fmtDate(_birthDate!),
            locked: _birthDateLocked,
            onTap: _birthDateLocked ? null : _pickBirthDate,
          ),
          const SizedBox(height: 12),
          _EditFieldCard(
            label: "Email",
            controller: _email,
            hintText: "example@mail.com",
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final firstName = _firstName.text.trim();
                final phone = _normalizePhone(_phone.text);
                final email = _email.text.trim();
                if (firstName.isEmpty ||
                    !_isValidPhone(phone) ||
                    email.isEmpty ||
                    !email.contains("@")) {
                  showAppNotice(
                    context,
                    "Заполните имя, телефон и корректную почту",
                    isError: true,
                  );
                  return;
                }

                try {
                  await context.read<AppState>().updateCurrentUserProfile(
                    firstName: firstName,
                    lastName: _lastName.text.trim(),
                    phone: phone,
                    email: email,
                    gender: _gender,
                    birthDate: _birthDate,
                    photoDataUri: _photoDataUri,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  showAppNotice(context, "Ошибка: $e", isError: true);
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text("Сохранить"),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, "0");
    return "${two(date.day)}.${two(date.month)}.${date.year}";
  }
}

class _ProfileAvatar extends StatelessWidget {
  final AppUser user;
  final double size;

  const _ProfileAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = _dataImageProvider(user.photoDataUri);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? Icon(Icons.person_outline, color: scheme.primary, size: 30)
          : null,
    );
  }
}

class _EditableProfileAvatar extends StatelessWidget {
  final String? photoDataUri;
  final double size;

  const _EditableProfileAvatar({
    required this.photoDataUri,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = _dataImageProvider(photoDataUri);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? Icon(Icons.person_outline, color: scheme.primary, size: 42)
          : null,
    );
  }
}

ImageProvider<Object>? _dataImageProvider(String? value) {
  final trimmed = value?.trim() ?? "";
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith("data:image")) return NetworkImage(trimmed);
  final commaIndex = trimmed.indexOf(",");
  if (commaIndex == -1) return null;
  try {
    return MemoryImage(base64Decode(trimmed.substring(commaIndex + 1)));
  } catch (_) {
    return null;
  }
}

class _EditFieldCard extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool isDark;
  final List<TextInputFormatter>? inputFormatters;

  const _EditFieldCard({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.isDark,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.88)
            : scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.24 : 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isCollapsed: true,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BelarusPhoneFormatter extends TextInputFormatter {
  const _BelarusPhoneFormatter();

  static String formatFromDigits(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final withoutCountry = digits.startsWith('375')
        ? digits.substring(3)
        : digits;
    final local = withoutCountry.length > 9
        ? withoutCountry.substring(0, 9)
        : withoutCountry;
    final buffer = StringBuffer('+375');

    if (local.isNotEmpty) {
      buffer.write(' ');
      buffer.write(local.substring(0, local.length.clamp(0, 2)));
    }
    if (local.length > 2) {
      buffer.write(' ');
      buffer.write(local.substring(2, local.length.clamp(2, 5)));
    }
    if (local.length > 5) {
      buffer.write('-');
      buffer.write(local.substring(5, local.length.clamp(5, 7)));
    }
    if (local.length > 7) {
      buffer.write('-');
      buffer.write(local.substring(7, local.length.clamp(7, 9)));
    }

    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatFromDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _GenderFieldCard extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _GenderFieldCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.88)
            : scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Пол",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GenderOptionCard(
                  title: "Мужской",
                  selected: value == "male",
                  onTap: () => onChanged("male"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderOptionCard(
                  title: "Женский",
                  selected: value == "female",
                  onTap: () => onChanged("female"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderOptionCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOptionCard({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.95)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.7)
                : scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateFieldCard extends StatelessWidget {
  final String? value;
  final bool locked;
  final VoidCallback? onTap;

  const _DateFieldCard({
    required this.value,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHigh.withValues(alpha: 0.88)
              : scheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.24 : 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Дата рождения",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value ?? "Выберите дату",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              locked ? Icons.lock_outline : Icons.calendar_month_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("О нас")),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "Раздел готов. Пришлите текст для блока «О нас», и я сразу его сюда вставлю.",
        ),
      ),
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
