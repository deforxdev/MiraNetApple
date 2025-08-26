import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'search_page.dart';
import 'add_post_page.dart';
import 'profile_page.dart';
import 'activity_page.dart';
import 'messages_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = [
    const _FeedPlaceholder(),
    const SearchPage(),
    const AddPostPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MiraNet',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: _index == 3
            ? [
                IconButton(
                  tooltip: 'Додати пост',
                  icon: const Icon(Icons.add_box_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddPostPage()),
                  ),
                ),
                IconButton(
                  tooltip: 'Налаштування',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Активність',
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActivityPage()),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Повідомлення',
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MessagesPage()),
                    );
                  },
                ),
              ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Головна'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Пошук'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'Додати'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профіль'),
        ],
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Стрічка постів буде тут…'),
    );
  }
}
