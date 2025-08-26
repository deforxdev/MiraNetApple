import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static SupabaseClient get _supa => Supabase.instance.client;

  static Future<bool> canChangeUsername(String userId) async {
    final row = await _supa.from('profiles').select('last_username_change_at').eq('id', userId).maybeSingle();
    final last = row?['last_username_change_at'] as String?;
    if (last == null) return true;
    final dt = DateTime.tryParse(last);
    if (dt == null) return true;
    return DateTime.now().difference(dt) > const Duration(days: 30);
  }

  static Future<bool> canChangeDisplayName(String userId) async {
    final row = await _supa.from('profiles').select('last_display_name_change_at').eq('id', userId).maybeSingle();
    final last = row?['last_display_name_change_at'] as String?;
    if (last == null) return true;
    final dt = DateTime.tryParse(last);
    if (dt == null) return true;
    return DateTime.now().difference(dt) > const Duration(days: 5);
  }

  static Future<String?> updateUsername(String newUsername) async {
    final me = _supa.auth.currentUser;
    if (me == null) return 'not_signed_in';
    final can = await canChangeUsername(me.id);
    if (!can) return 'cooldown';
    try {
      await _supa.from('profiles').update({
        'username': newUsername,
        'last_username_change_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', me.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> updateDisplayName(String newName) async {
    final me = _supa.auth.currentUser;
    if (me == null) return 'not_signed_in';
    final can = await canChangeDisplayName(me.id);
    if (!can) return 'cooldown';
    try {
      // keep in auth metadata (optional) and in profiles
      await _supa.auth.updateUser(UserAttributes(data: {'display_name': newName}));
      await _supa.from('profiles').update({
        'display_name': newName,
        'last_display_name_change_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', me.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> blockUser(String targetId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return;
    if (me.id == targetId) return;
    await _supa.from('blocks').insert({'blocker_id': me.id, 'blocked_id': targetId});
  }

  static Future<void> unblockUser(String targetId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return;
    await _supa.from('blocks').delete().eq('blocker_id', me.id).eq('blocked_id', targetId);
  }

  static Future<bool> isBlocked(String targetId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return false;
    final r = await _supa
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', me.id)
        .eq('blocked_id', targetId)
        .maybeSingle();
    return r != null;
  }

  static Future<List<Map<String, dynamic>>> listBlockedProfiles() async {
    final me = _supa.auth.currentUser;
    if (me == null) return [];
    try {
      final rows = await _supa
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', me.id);
      final ids = (rows as List)
          .map((e) => e['blocked_id'] as String?)
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return [];
    final profs = await _supa
      .from('profiles')
      .select('id, display_name, username, avatar_path')
      .inFilter('id', ids);
      return (profs as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // ignore: avoid_print
      print('listBlockedProfiles error: $e');
      return [];
    }
  }
}
