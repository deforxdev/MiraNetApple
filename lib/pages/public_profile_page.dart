import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import 'package:flutter/services.dart';
import '../services/chat_service.dart';
import 'messages_page.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;
  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _isFollowing = false;
  int _posts = 0;
  int _followers = 0;
  int _following = 0;
  List<Map<String, dynamic>> _postsRows = const [];
  String? _meId;
  bool _blockedEitherWay = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
  _meId = Supabase.instance.client.auth.currentUser?.id;
    _loadCountsAndFollow();
    _loadPosts();
    _checkBlocked();
  }

  Future<void> _checkBlocked() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    try {
      // if either side blocked, queries for posts/profiles might already be filtered by RLS; but we also add UI gate
      final r1 = await Supabase.instance.client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', me.id)
          .eq('blocked_id', widget.userId)
          .maybeSingle();
      final r2 = await Supabase.instance.client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', widget.userId)
          .eq('blocked_id', me.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _blockedEitherWay = (r1 != null) || (r2 != null);
      });
    } catch (_) {}
  }

  Future<void> _loadCountsAndFollow() async {
    final c = await SocialService.counts(widget.userId);
    final isF = await SocialService.isFollowing(widget.userId);
    if (!mounted) return;
    setState(() {
      _posts = c.posts;
      _followers = c.followers;
      _following = c.following;
      _isFollowing = isF;
    });
  }

  Future<void> _loadPosts() async {
    final rows = await SocialService.userPosts(widget.userId);
    if (!mounted) return;
    setState(() {
      _postsRows = rows;
    });
  }

  Future<void> _toggleFollow() async {
    if (_isFollowing) {
      await SocialService.unfollow(widget.userId);
    } else {
      await SocialService.follow(widget.userId);
    }
    await _loadCountsAndFollow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'block') {
                await UserService.blockUser(widget.userId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Користувача заблоковано')));
                setState(() => _blockedEitherWay = true);
              } else if (v == 'report') {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скаргу відправлено')));
              } else if (v == 'info') {
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => const AlertDialog(title: Text('Інформація'), content: Text('Публічні дані акаунта.')),
                );
              } else if (v == 'copy') {
                final link = 'miranet://profile/${widget.userId}';
                await Clipboard.setData(ClipboardData(text: link));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Посилання скопійовано')));
              } else if (v == 'unblock') {
                await UserService.unblockUser(widget.userId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Користувача розблоковано')));
                setState(() => _blockedEitherWay = false);
              }
            },
            itemBuilder: (ctx) => [
              if (_blockedEitherWay)
                const PopupMenuItem(value: 'unblock', child: Text('Розблокувати'))
              else
                const PopupMenuItem(value: 'block', child: Text('Заблокувати')),
              const PopupMenuItem(value: 'report', child: Text('Поскаржитись')),
              const PopupMenuItem(value: 'info', child: Text('Інформація про акаунт')),
              const PopupMenuItem(value: 'copy', child: Text('Копіювати посилання')),
            ],
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ProfileService.fetchProfile(widget.userId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: Text('Профіль не знайдено'));
          }
          final display = (data['display_name'] as String?) ?? '';
          final handle = (data['username'] as String?) ?? '';
          final path = (data['avatar_path'] as String?) ?? '';
          _isAdmin = handle.toLowerCase() == 'gg4512323';
          if (_blockedEitherWay && _meId != data['id']) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.block, size: 48),
                  SizedBox(height: 8),
                  Text('Користувач заблокований'),
                ],
              ),
            );
          }
          return FutureBuilder<String?>(
            future: ProfileService.signedAvatarUrl(path),
            builder: (context, s2) {
              final url = s2.data;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
                          child: (url == null || url.isEmpty) ? const Icon(Icons.person, size: 40) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(display.isNotEmpty ? display : (handle.isNotEmpty ? handle : '')),
                                  if (_isAdmin) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Це адмін акаунт')),
                                        );
                                      },
                                      child: Tooltip(
                                        message: 'Адмін',
                                        child: Icon(Icons.verified, color: Colors.amber.shade400, size: 18),
                                      ),
                                    )
                                  ]
                                ],
                              ),
                              if (handle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('@$handle', style: Theme.of(context).textTheme.bodySmall),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _Stat(title: 'Пости', value: _posts),
                                _Stat(title: 'Підписники', value: _followers),
                                _Stat(title: 'Підписки', value: _following),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_meId != data['id'] && !_blockedEitherWay)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 360;
                          final followBtn = FilledButton(
                            onPressed: _toggleFollow,
                            child: Text(_isFollowing ? 'Відписатися' : 'Підписатися'),
                          );
                          final msgBtn = OutlinedButton(
                            onPressed: () async {
                              final chatId = await ChatService.ensureDirectChat(widget.userId);
                              if (chatId == null) return;
                              if (!mounted) return;
                              final title = display.isNotEmpty ? display : (handle.isNotEmpty ? '@$handle' : 'Чат');
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId, title: title)),
                              );
                            },
                            child: const Text('Повідомлення'),
                          );
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                followBtn,
                                const SizedBox(height: 8),
                                msgBtn,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: followBtn),
                              const SizedBox(width: 8),
                              Expanded(child: msgBtn),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _postsRows.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (context, i) {
                        final row = _postsRows[i];
                        final imgPath = (row['image_path'] as String?) ?? '';
                        return FutureBuilder<String?>(
                          future: SocialService.signedPostUrl(imgPath),
                          builder: (context, su) {
                            final purl = su.data;
                            return Container(
                              color: Colors.grey.shade800,
                              child: (purl != null && purl.isNotEmpty)
                                  ? Image.network(purl, fit: BoxFit.cover)
                                  : const Icon(Icons.image),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
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
