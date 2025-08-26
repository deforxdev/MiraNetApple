import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static SupabaseClient get _supa => Supabase.instance.client;

  // Ensure a direct chat between current user and target exists, returns chat_id
  static Future<String?> ensureDirectChat(String targetUserId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return null;
      final res = await _supa.rpc('ensure_direct_chat', params: {
        'p_other': targetUserId,
      });
      return res as String;
  }

  static Future<List<Map<String, dynamic>>> listMyChats() async {
    final me = _supa.auth.currentUser;
    if (me == null) return [];
    final rows = await _supa.from('chats')
      .select('id, is_direct, created_at')
      .order('created_at')
      .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static Stream<List<Map<String, dynamic>>> messageStream(String chatId) {
    final stream = _supa
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
  .order('created_at', ascending: false);
    return stream.map((rows) => rows.cast<Map<String, dynamic>>());
  }

  static Future<String?> getChatPeer(String chatId) async {
    final res = await _supa.rpc('get_chat_peer', params: {'p_chat': chatId});
    return res as String?;
  }

  static Future<void> sendMessage(String chatId, String text) async {
    final me = _supa.auth.currentUser;
    if (me == null) return;
    if (text.trim().isEmpty) return;
    await _supa.from('messages').insert({
      'chat_id': chatId,
      'sender_id': me.id,
      'text': text.trim(),
    });
  }
}
