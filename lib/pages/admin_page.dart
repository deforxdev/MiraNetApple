import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  bool _isAdminUser() {
    final u = Supabase.instance.client.auth.currentUser;
    final handle = (u?.userMetadata?['username'] as String?) ?? u?.email ?? '';
    final h = handle.toString().toLowerCase();
    return h.contains('deforxx') || h.contains('gg4512323');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdminUser()) {
      return const Scaffold(
        body: Center(child: Text('Доступ заборонено')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Адмін')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(title: Text('Панель адміністратора')), 
          SizedBox(height: 8),
          Text('Тут з’являться інструменти модерації.'),
        ],
      ),
    );
  }
}
