import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<void> ensureProfileForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final md = user.userMetadata ?? {};
    final displayName = (md['display_name'] as String?) ?? user.email?.split('@').first ?? 'user';
    final avatarPath = (md['avatar_path'] as String?) ?? '';
  final username = user.email?.split('@').first ?? displayName;
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName,
    'username': username.replaceAll('@', '').toLowerCase(),
        'avatar_path': avatarPath,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      // ignore: avoid_print
      print('ensureProfileForCurrentUser error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    var q = query.trim();
    if (q.length < 2) return [];
  // Escape special chars for ILIKE; use asterisk wildcards per PostgREST examples
  q = q
    .replaceAll('\\\\', '\\\\')
    .replaceAll('*', '\\*')
    .replaceAll('_', '\\_');
  final pattern = '*$q*';
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, display_name, username, avatar_path')
          .or('display_name.ilike.$pattern,username.ilike.$pattern')
          .limit(25);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // ignore: avoid_print
      print('searchProfiles error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchProfile(String id) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, display_name, username, avatar_path')
          .eq('id', id)
          .maybeSingle();
  return data;
    } catch (e) {
      // ignore: avoid_print
      print('fetchProfile error: $e');
      return null;
    }
  }

  static Future<String?> signedAvatarUrl(String? path, {int expiresInSeconds = 60 * 60 * 24 * 7}) async {
    if (path == null || path.isEmpty) return null;
    try {
      final url = await _supabase.storage.from('avatars').createSignedUrl(path, expiresInSeconds);
      return url;
    } catch (e) {
      // ignore: avoid_print
      print('signedAvatarUrl error: $e');
      return null;
    }
  }
}
