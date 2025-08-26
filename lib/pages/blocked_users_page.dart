import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/profile_service.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = UserService.listBlockedProfiles();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = UserService.listBlockedProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заблоковані')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('Немає заблокованих'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = items[i];
                final id = p['id'] as String;
                final display = (p['display_name'] as String?) ?? '';
                final handle = (p['username'] as String?) ?? '';
                final path = (p['avatar_path'] as String?) ?? '';
                return FutureBuilder<String?>(
                  future: ProfileService.signedAvatarUrl(path),
                  builder: (context, s2) {
                    final url = s2.data;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
                        child: (url == null || url.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      title: Text(display.isNotEmpty ? display : handle),
                      subtitle: Text('@$handle'),
                      trailing: TextButton(
                        onPressed: () async {
                          await UserService.unblockUser(id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Розблоковано')));
                          await _refresh();
                        },
                        child: const Text('Розблокувати'),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
