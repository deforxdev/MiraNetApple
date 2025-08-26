import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String? title;
  const ChatPage({super.key, required this.chatId, this.title});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Map<String, dynamic>? _peer;

  @override
  void initState() {
    super.initState();
    _loadPeer();
  }

  Future<void> _loadPeer() async {
    final peerId = await ChatService.getChatPeer(widget.chatId);
    if (peerId == null) return;
    final p = await ProfileService.fetchProfile(peerId);
    if (p == null) return;
    final avatar = await ProfileService.signedAvatarUrl(p['avatar_path'] as String?);
    if (!mounted) return;
    setState(() {
      _peer = {
        'id': peerId,
        'display_name': p['display_name'],
        'username': p['username'],
        'avatar_url': avatar,
      };
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
  _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final titleWidget = _peer == null
        ? Text(widget.title ?? 'Чат')
        : Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: (_peer!['avatar_url'] as String?) != null
                    ? NetworkImage(_peer!['avatar_url'])
                    : null,
                child: (_peer!['avatar_url'] as String?) == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (_peer!['display_name'] as String?) ?? 'Користувач',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '@${(_peer!['username'] as String?) ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: titleWidget),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ChatService.messageStream(widget.chatId),
              builder: (context, snap) {
                final msgsDesc = snap.data ?? const [];
                final msgs = msgsDesc.reversed.toList(growable: false); // oldest -> newest
                // Auto-jump to bottom when new data arrives
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final m = msgs[i];
                    final mine = m['sender_id'] == me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: mine ? Colors.indigo : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (m['text'] as String?) ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(hintText: 'Повідомлення...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      final text = _ctrl.text;
                      if (text.trim().isEmpty) return;
                      _ctrl.clear();
                      try {
                        await ChatService.sendMessage(widget.chatId, text);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Помилка відправки: ${e.toString()}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.send),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Повідомлення')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ChatService.listMyChats(),
        builder: (context, snap) {
          final chats = snap.data ?? const [];
          if (chats.isEmpty) {
            return const Center(child: Text('Поки що немає чатів'));
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final row = chats[i];
              final chatId = row['id'] as String?;
              final title = 'Діалог';
              return ListTile(
                title: Text(title),
                onTap: () {
                  if (chatId != null && chatId.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId)),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Новий діалог',
        child: const Icon(Icons.chat_bubble_outline),
        onPressed: () async {
          // Simple prompt for target userId; later replace with search+pick
          final controller = TextEditingController();
          final target = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Почати діалог'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Введіть userId співрозмовника'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
                FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Почати')),
              ],
            ),
          );
          if (target == null || target.isEmpty) return;
          final chatId = await ChatService.ensureDirectChat(target);
          if (chatId == null) return;
          // Go to chat
          // ignore: use_build_context_synchronously
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId)));
        },
      ),
    );
  }
}
