import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  static SupabaseClient get _supa => Supabase.instance.client;

  static String _randId([int len = 16]) {
    const chars = 'abcdef0123456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _guessContentType(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    if (e == 'webp') return 'image/webp';
    if (e == 'mp3') return 'audio/mpeg';
    if (e == 'm4a' || e == 'aac') return 'audio/aac';
    if (e == 'wav') return 'audio/wav';
    return 'application/octet-stream';
  }

  /// Creates a post with required image, optional caption, filterName, optional music,
  /// optional list of tagged user ids, and optional poll (question + options >= 2).
  static Future<String> createPost({
    required Uint8List imageBytes,
    required String imageExt,
    String? caption,
    String? filterName,
    Uint8List? musicBytes,
    String? musicExt,
    List<String>? tagUserIds,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    final me = _supa.auth.currentUser;
    if (me == null) throw 'not_signed_in';

    final imageId = _randId(24);
    final imgExt = imageExt.replaceAll('.', '').toLowerCase();
    final imagePath = '${me.id}/posts/$imageId.$imgExt';
    await _supa.storage.from('posts').uploadBinary(
      imagePath,
      imageBytes,
      fileOptions: FileOptions(contentType: _guessContentType(imgExt)),
    );

    String? musicPath;
    if (musicBytes != null && musicBytes.isNotEmpty && musicExt != null && musicExt.isNotEmpty) {
      final musicId = _randId(24);
      final mExt = musicExt.replaceAll('.', '').toLowerCase();
      musicPath = '${me.id}/music/$musicId.$mExt';
      await _supa.storage.from('posts').uploadBinary(
        musicPath,
        musicBytes,
        fileOptions: FileOptions(contentType: _guessContentType(mExt)),
      );
    }

    // Insert post
    final row = await _supa.from('posts').insert({
      'user_id': me.id,
      'image_path': imagePath,
      'caption': caption,
      'filter_name': filterName,
      'music_path': musicPath,
    }).select('id').single();
    final postId = row['id'] as String;

    // Tags
    final tags = (tagUserIds ?? []).where((s) => s.isNotEmpty).toList();
    if (tags.isNotEmpty) {
      await _supa.from('post_tags').insert(
        tags.map((u) => {'post_id': postId, 'user_id': u}).toList(),
      );
    }

    // Poll
    final options = (pollOptions ?? []).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if ((pollQuestion != null && pollQuestion.trim().isNotEmpty) && options.length >= 2) {
      await _supa.from('posts_polls').insert({'post_id': postId, 'question': pollQuestion.trim()});
      await _supa.from('posts_poll_options').insert(
        options.map((t) => {'post_id': postId, 'text': t}).toList(),
      );
    }

    return postId;
  }
}
