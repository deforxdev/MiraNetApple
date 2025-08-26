import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../services/user_service.dart';
import '../services/social_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editing = false;
  late TextEditingController _nickCtrl;
  late TextEditingController _usernameCtrl;
  String _avatarUrlLocal = '';
  String _avatarPathLocal = '';
  int _posts = 0;
  int _followers = 0;
  int _following = 0;
  late String _handle;
  bool _saving = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
  final metadata = user?.userMetadata ?? {};
    final nick = (metadata['display_name'] as String?) ?? user?.email?.split('@').first ?? 'user';
  _handle = (metadata['username'] as String?) ?? (user?.email?.split('@').first ?? nick);
    _avatarUrlLocal = (metadata['avatar_url'] as String?) ?? '';
    _avatarPathLocal = (metadata['avatar_path'] as String?) ?? '';
    _nickCtrl = TextEditingController(text: nick);
  _usernameCtrl = TextEditingController(text: _handle.startsWith('@') ? _handle : '@$_handle');
  final email = (user?.email ?? '').toLowerCase();
  // Admins: specific handles or email local part
  final h = _handle.toLowerCase().replaceAll('@', '');
  _isAdmin = email.startsWith('deforxx') || h == 'gg4512323';
    // Якщо є шлях у сховищі, згенеруємо підписаний URL для відображення (підтримка приватних бакетів)
    if (_avatarPathLocal.isNotEmpty) {
      _loadSignedUrl(_avatarPathLocal);
    }
  _loadCounts();
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
  _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final c = await SocialService.counts(user.id);
    if (!mounted) return;
    setState(() {
      _posts = c.posts;
      _followers = c.followers;
      _following = c.following;
    });
  }

  Future<void> _pickAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
  final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;

    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
    try {
    final lower = (f.extension ?? '').toLowerCase();
    final guessed = lower == 'png'
      ? 'image/png'
      : (lower == 'jpg' || lower == 'jpeg')
        ? 'image/jpeg'
        : 'image/*';
    await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
      fileOptions: FileOptions(upsert: true, contentType: guessed),
          );
      _avatarPathLocal = path;
      // Згенерувати підписаний URL для попереднього перегляду
      final signed = await Supabase.instance.client.storage.from('avatars').createSignedUrl(path, 60 * 60 * 24 * 7);
      if (!mounted) return;
      setState(() {
        _avatarUrlLocal = signed;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Помилка завантаження: $e')));
    }
  }

  Future<void> _saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'display_name': _nickCtrl.text.trim(),
      };
      if (_avatarPathLocal.isNotEmpty) {
        data['avatar_path'] = _avatarPathLocal;
      }
      // Update display name with cooldown
      final dnErr = await UserService.updateDisplayName(_nickCtrl.text.trim());
      if (dnErr == 'cooldown') {
        throw 'Імʼя можна змінювати раз на 5 днів';
      }
      if (dnErr != null && dnErr != 'not_signed_in') {
        throw dnErr;
      }
      // Update username with @ prefix and 30-day cooldown
      final raw = _usernameCtrl.text.trim();
      final withAt = raw.startsWith('@') ? raw : '@$raw';
      final normalized = withAt.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (normalized.length < 3) {
        throw 'Нік занадто короткий';
      }
      final unErr = await UserService.updateUsername(normalized.startsWith('@') ? normalized.substring(1) : normalized);
      if (unErr == 'cooldown') {
        throw 'Нік @ можна змінювати раз на 30 днів';
      }
      if (unErr != null && unErr != 'not_signed_in') {
        throw unErr;
      }
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {
        ...data,
        'username': normalized.startsWith('@') ? normalized.substring(1) : normalized,
      }));
      if (!mounted) return;
      setState(() {
        _editing = false;
        _handle = normalized.startsWith('@') ? normalized.substring(1) : normalized;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка збереження: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadSignedUrl(String path) async {
    try {
      final signed = await Supabase.instance.client.storage.from('avatars').createSignedUrl(path, 60 * 60 * 24 * 7);
      if (!mounted) return;
      setState(() => _avatarUrlLocal = signed);
    } catch (_) {
      // ignore
    }
  }
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
  final metadata = user?.userMetadata ?? {};
  final avatarUrl = _avatarUrlLocal.isNotEmpty ? _avatarUrlLocal : (metadata['avatar_url'] as String?) ?? '';
  final nick = _nickCtrl.text;
  final posts = _posts;
  final followers = _followers;
  final following = _following;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: _editing ? _pickAvatar : null,
                borderRadius: BorderRadius.circular(40),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade700,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_editing)
                      TextField(
                        controller: _nickCtrl,
                        decoration: const InputDecoration(labelText: 'Імʼя профілю'),
                      )
                    else
                      Row(
                        children: [
                          Text(nick, style: Theme.of(context).textTheme.titleMedium),
                          if (_isAdmin) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Адмін',
                              child: Icon(Icons.verified, color: Colors.amber.shade400, size: 18),
                            )
                          ]
                        ],
                      ),
                    const SizedBox(height: 4),
                    if (_editing)
                      TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(labelText: 'Нік (@username)'),
                      )
                    else
                      Text('@${_handle.replaceAll('@', '')}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Stat(title: 'Пости', value: posts),
                  const SizedBox(width: 16),
                  _Stat(title: 'Підписники', value: followers),
                  const SizedBox(width: 16),
                  _Stat(title: 'Підписки', value: following),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _editing = !_editing);
                  },
                  child: Text(_editing ? 'Скасувати' : 'Редагувати профіль'),
                ),
              ),
              if (_editing) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Зберегти'),
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // Сітка постів (плейсхолдер)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, i) {
              return Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.image, size: 28),
              );
            },
          )
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final int value;
  const _Stat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
