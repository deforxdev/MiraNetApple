import 'package:supabase_flutter/supabase_flutter.dart';

class SocialService {
  static SupabaseClient get _supa => Supabase.instance.client;

  static Future<({int posts, int followers, int following})> counts(String userId) async {
    try {
      final pc = await _supa.rpc('posts_count', params: {'p_user': userId});
      final frc = await _supa.rpc('followers_count', params: {'p_user': userId});
      final fgc = await _supa.rpc('following_count', params: {'p_user': userId});
      return (
        posts: (pc as num?)?.toInt() ?? 0,
        followers: (frc as num?)?.toInt() ?? 0,
        following: (fgc as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      // ignore: avoid_print
      print('counts error: $e');
      return (posts: 0, followers: 0, following: 0);
    }
  }

  static Future<bool> isFollowing(String targetUserId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return false;
    try {
      final r = await _supa.rpc('is_following', params: {
        'p_follower': me.id,
        'p_following': targetUserId,
      });
      return (r as bool?) ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('isFollowing error: $e');
      return false;
    }
  }

  static Future<void> follow(String targetUserId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return;
    try {
      await _supa.from('follows').insert({
        'follower_id': me.id,
        'following_id': targetUserId,
      });
    } catch (e) {
      // ignore: avoid_print
      print('follow error: $e');
    }
  }

  static Future<void> unfollow(String targetUserId) async {
    final me = _supa.auth.currentUser;
    if (me == null) return;
    try {
      await _supa
          .from('follows')
          .delete()
          .eq('follower_id', me.id)
          .eq('following_id', targetUserId);
    } catch (e) {
      // ignore: avoid_print
      print('unfollow error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> userPosts(String userId) async {
    try {
      final rows = await _supa
          .from('posts')
          .select('id, image_path, caption, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // ignore: avoid_print
      print('userPosts error: $e');
      return [];
    }
  }

  static Future<String?> signedPostUrl(String path, {int expiresInSeconds = 60 * 60 * 24 * 7}) async {
    if (path.isEmpty) return null;
    try {
      final url = await _supa.storage.from('posts').createSignedUrl(path, expiresInSeconds);
      return url;
    } catch (e) {
      // ignore: avoid_print
      print('signedPostUrl error: $e');
      return null;
    }
  }
}
