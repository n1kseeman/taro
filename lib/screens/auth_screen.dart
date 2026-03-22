import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../ui/app_notice.dart';
import 'admin/admin_menu_editor_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Профиль"),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: "Вход"),
            Tab(text: "Регистрация"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildLogin(context, s), _buildRegister(context, s)],
      ),
    );
  }

  Widget _buildLogin(BuildContext context, AppState s) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _loginEmail,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _loginPass,
            decoration: const InputDecoration(labelText: "Пароль"),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final loginOrEmail = _loginEmail.text.trim();
                final password = _loginPass.text;

                try {
                  // если нет @ — считаем, что это админ-логин
                  if (!loginOrEmail.contains("@")) {
                    final ok = await s.adminLoginByCredentials(
                      login: loginOrEmail,
                      password: password,
                    );

                    if (!ok) {
                      throw Exception("Wrong admin credentials");
                    }

                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminMenuEditorScreen(),
                      ),
                      (_) => false,
                    );
                    return;
                  }

                  // иначе обычный пользователь
                  await s.login(email: loginOrEmail, password: password);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  showAppNotice(context, "Ошибка: $e", isError: true);
                }
              },
              child: const Text("Войти"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegister(BuildContext context, AppState s) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _regName,
            decoration: const InputDecoration(labelText: "Имя"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _regEmail,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _regPass,
            decoration: const InputDecoration(labelText: "Пароль"),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                try {
                  await s.register(
                    email: _regEmail.text.trim(),
                    password: _regPass.text,
                    name: _regName.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  showAppNotice(context, "Ошибка: $e", isError: true);
                }
              },
              child: const Text("Создать аккаунт"),
            ),
          ),
        ],
      ),
    );
  }
}
