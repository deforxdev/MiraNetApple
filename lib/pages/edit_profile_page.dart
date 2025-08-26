import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nickCtrl;
  String _avatarUrl = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final md = user?.userMetadata ?? {};
    _nickCtrl = TextEditingController(text: (md['display_name'] as String?) ?? user?.email?.split('@').first ?? '');
    _avatarUrl = (md['avatar_url'] as String?) ?? '';
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
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
    final path = 'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
    try {
      await Supabase.instance.client.storage.from('public').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/*'),
          );
      final publicUrl = Supabase.instance.client.storage.from('public').getPublicUrl(path);
      setState(() => _avatarUrl = publicUrl);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Помилка завантаження: $e')));
    }
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'display_name': _nickCtrl.text.trim(),
          'avatar_url': _avatarUrl,
        }),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка збереження: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редагувати профіль')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade700,
                      backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                      child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 48) : null,
                    ),
                    IconButton(
                      tooltip: 'Змінити аватар',
                      icon: const Icon(Icons.camera_alt_outlined),
                      onPressed: _pickAvatar,
                    )
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nickCtrl,
                  decoration: const InputDecoration(labelText: 'Нік'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Зберегти'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
