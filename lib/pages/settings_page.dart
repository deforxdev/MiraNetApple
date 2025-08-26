import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/theme_service.dart';
import 'admin_page.dart';
import '../services/user_service.dart';
import 'blocked_users_page.dart';
import 'privacy_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  @override
  Widget build(BuildContext context) {
    final u = Supabase.instance.client.auth.currentUser;
    final handle = (u?.userMetadata?['username'] as String?) ?? u?.email ?? '';
    final isAdmin = handle.toString().toLowerCase().contains('deforxx') || handle.toString().toLowerCase().contains('gg4512323');
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAdmin)
            ListTile(
              leading: Icon(Icons.verified, color: Colors.amber.shade400),
              title: const Text('Адмін-панель'),
              subtitle: const Text('Ви адміністратор цього застосунку'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPage())),
            ),
          if (isAdmin) const Divider(),
          const Text('Тема', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.mode,
            builder: (context, mode, _) => Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Темна'),
                  value: ThemeMode.dark,
                  groupValue: mode,
                  onChanged: (m) => ThemeService.set(m!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Світла'),
                  value: ThemeMode.light,
                  groupValue: mode,
                  onChanged: (m) => ThemeService.set(m!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Системна'),
                  value: ThemeMode.system,
                  groupValue: mode,
                  onChanged: (m) => ThemeService.set(m!),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Конфіденційність і підписки'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPage()),
            ),
          ),
          const Divider(),
          const Text('Нікнейм', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _UsernameEditor(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Заблоковані акаунти'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersPage()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Вийти з акаунта'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Видалити акаунт'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Видалити акаунт?'),
                  content: const Text('Цю дію не можна скасувати.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Видалити')),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                final user = Supabase.instance.client.auth.currentUser;
                if (user != null) {
                  // Auth API requires service role to truly delete; here sign out and ask admin flow.
                  await Supabase.instance.client.auth.signOut();
                }
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
              }
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Керування нікнеймом'),
            subtitle: Text('Нік починається з @. Зміна @нік — раз на 30 днів; імʼя профілю — раз на 5 днів.'),
          )
        ],
      ),
    );
  }
}

class _UsernameEditor extends StatefulWidget {
  @override
  State<_UsernameEditor> createState() => _UsernameEditorState();
}

class _UsernameEditorState extends State<_UsernameEditor> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = Supabase.instance.client.auth.currentUser;
    final md = u?.userMetadata ?? {};
    final handle = (md['username'] as String?) ?? u?.email?.split('@').first ?? '';
    _ctrl = TextEditingController(text: handle.startsWith('@') ? handle : '@$handle');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final raw = _ctrl.text.trim();
      final withAt = raw.startsWith('@') ? raw : '@$raw';
      final normalized = withAt.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (normalized.length < 3) {
        throw 'Нік занадто короткий';
      }
      final err = await UserService.updateUsername(normalized.substring(1));
      if (err == 'cooldown') throw 'Нік @ можна змінювати раз на 30 днів';
      if (err != null && err != 'not_signed_in') throw err;
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {
        'username': normalized.substring(1),
      }));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нік оновлено')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(labelText: 'Нік (@username)'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Зберегти'),
        )
      ],
    );
  }
}
