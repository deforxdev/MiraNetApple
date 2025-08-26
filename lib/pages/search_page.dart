import 'dart:async';
import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      final data = await ProfileService.searchProfiles(v);
      if (!mounted) return;
      setState(() {
        _results = data;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: 'Пошук акаунтів',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = _results[i];
                final display = (r['display_name'] as String?) ?? '';
                final handle = (r['username'] as String?) ?? '';
                final avatarPath = (r['avatar_path'] as String?) ?? '';
                return FutureBuilder<String?>(
                  future: ProfileService.signedAvatarUrl(avatarPath),
                  builder: (context, snap) {
                    final url = snap.data;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
                        child: (url == null || url.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      title: Text(display.isNotEmpty ? display : handle),
                      subtitle: handle.isNotEmpty ? Text('@$handle') : null,
                      onTap: () {
                        Navigator.of(context).pushNamed('/public-profile', arguments: r['id'] as String);
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
