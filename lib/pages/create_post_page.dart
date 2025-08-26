import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/post_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  Uint8List? _image;
  String? _imageExt;
  Uint8List? _music;
  String? _musicExt;
  String? _filter;
  final _caption = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [TextEditingController(), TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    _tagCtrl.dispose();
    for (final c in _pollOptions) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _image = res.files.single.bytes!;
        _imageExt = res.files.single.extension ?? 'jpg';
      });
    }
  }

  Future<void> _pickMusic() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _music = res.files.single.bytes!;
        _musicExt = res.files.single.extension ?? 'mp3';
      });
    }
  }

  Widget _imagePreview() {
    if (_image == null) {
      return Container(
        height: 260,
        color: Colors.grey.shade900,
        child: const Center(child: Text('Виберіть зображення')),
      );
    }
    // Simple filter simulation via ColorFiltered
    ColorFilter? cf;
    switch (_filter) {
      case 'mono':
        cf = const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]);
        break;
      case 'warm':
        cf = const ColorFilter.mode(Color(0x33FF8A65), BlendMode.overlay);
        break;
      case 'cool':
        cf = const ColorFilter.mode(Color(0x3323A6D5), BlendMode.overlay);
        break;
      default:
        cf = null;
    }
    final img = Image.memory(_image!, fit: BoxFit.cover, width: double.infinity, height: 260);
    return Container(
      height: 260,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: cf == null ? img : ColorFiltered(colorFilter: cf, child: img),
    );
  }

  Future<void> _save() async {
    if (_image == null || _imageExt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Додайте фото')));
      return;
    }
    setState(() => _saving = true);
    try {
      final tagsText = _tagCtrl.text.trim();
      final tagIds = tagsText.isEmpty ? <String>[] : tagsText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final options = _pollOptions.map((c) => c.text).toList();
      final postId = await PostService.createPost(
        imageBytes: _image!,
        imageExt: _imageExt!,
        caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        filterName: _filter,
        musicBytes: _music,
        musicExt: _musicExt,
        tagUserIds: tagIds,
        pollQuestion: _pollQuestion.text.trim().isEmpty ? null : _pollQuestion.text.trim(),
        pollOptions: options,
      );
      if (!mounted) return;
      Navigator.of(context).pop(postId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Створити пост'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Опублікувати'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _imagePreview(),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo), label: const Text('Фото з галереї')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _pickMusic, icon: const Icon(Icons.music_note), label: const Text('Музика')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Без фільтра'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
              ChoiceChip(label: const Text('Mono'), selected: _filter == 'mono', onSelected: (_) => setState(() => _filter = 'mono')),
              ChoiceChip(label: const Text('Warm'), selected: _filter == 'warm', onSelected: (_) => setState(() => _filter = 'warm')),
              ChoiceChip(label: const Text('Cool'), selected: _filter == 'cool', onSelected: (_) => setState(() => _filter = 'cool')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            decoration: const InputDecoration(labelText: 'Опис (необовʼязково)'),
            maxLines: null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagCtrl,
            decoration: const InputDecoration(
              labelText: 'Позначити людей (введіть їх userId через кому, тимчасово)',
            ),
          ),
          const Divider(height: 32),
          const Text('Опитування (необовʼязково)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _pollQuestion,
            decoration: const InputDecoration(labelText: 'Питання'),
          ),
          const SizedBox(height: 8),
          ..._pollOptions.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(controller: c, decoration: const InputDecoration(labelText: 'Варіант')),
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _pollOptions.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Додати варіант'),
            ),
          ),
          const SizedBox(height: 24),
          if (me != null)
            Text('Публікація від: ${me.email}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
