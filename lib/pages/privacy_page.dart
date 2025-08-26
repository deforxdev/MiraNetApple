import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _loading = true;
  bool _isPrivate = false;
  bool _followersOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return;
    final row = await Supabase.instance.client
        .from('profiles')
        .select('is_private, messages_followers_only')
        .eq('id', u.id)
        .maybeSingle();
    setState(() {
      _loading = false;
      _isPrivate = (row?['is_private'] as bool?) ?? false;
      _followersOnly = (row?['messages_followers_only'] as bool?) ?? false;
    });
  }

  Future<void> _save() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'is_private': _isPrivate,
        'messages_followers_only': _followersOnly,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', u.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конфіденційність і підписки'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Зберегти'),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Приватний профіль'),
                  subtitle: const Text('Тільки підписники бачать ваші пости та підписки'),
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Повідомлення лише від підписників'),
                  subtitle: const Text('Лише ті, хто підписані на вас, можуть писати вам у ДМ'),
                  value: _followersOnly,
                  onChanged: (v) => setState(() => _followersOnly = v),
                ),
              ],
            ),
    );
  }
}
