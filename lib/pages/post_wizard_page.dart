import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/profile_service.dart';

class PostWizardPage extends StatefulWidget {
  const PostWizardPage({super.key});

  @override
  State<PostWizardPage> createState() => _PostWizardPageState();
}

class _PostWizardPageState extends State<PostWizardPage> {
  int _step = 0; // 0: select, 1: edit, 2: details

  // Media
  Uint8List? _origImage;
  String? _origImageExt;
  Uint8List? _music;
  String? _musicExt;

  // Editor state
  final GlobalKey _editKey = GlobalKey();
  String? _filter;
  String _overlayText = '';
  double _overlayFont = 24;
  Color _overlayColor = Colors.white;
  Offset _overlayPos = const Offset(50, 50);

  // Details
  final _caption = TextEditingController();
  final List<Map<String, String>> _tagged = []; // {id, label}
  bool _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _origImage = res.files.single.bytes!;
        _origImageExt = (res.files.single.extension ?? 'jpg').toLowerCase();
        _step = 1; // move to edit
      });
    }
  }

  Future<void> _pickMusic() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _music = res.files.single.bytes!;
        _musicExt = (res.files.single.extension ?? 'mp3').toLowerCase();
      });
    }
  }

  // Composition widget used both in Edit and Details steps
  Widget _buildComposition({double size = 320}) {
    final image = _origImage;
    if (image == null) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey.shade900,
        child: const Center(child: Text('Немає фото')),
      );
    }
    // Filters
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
      case 'sepia':
        cf = const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]);
        break;
      default:
        cf = null;
    }
    final baseImage = Image.memory(image, fit: BoxFit.cover, width: size, height: size);
    Widget composed = Stack(
      children: [
        Positioned.fill(child: cf == null ? baseImage : ColorFiltered(colorFilter: cf, child: baseImage)),
        if (_overlayText.isNotEmpty)
          Positioned(
            left: _overlayPos.dx,
            top: _overlayPos.dy,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  _overlayPos += d.delta;
                });
              },
              child: Text(
                _overlayText,
                style: TextStyle(
                  color: _overlayColor,
                  fontSize: _overlayFont,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1))],
                ),
              ),
            ),
          ),
      ],
    );
    // Square canvas with border radius in preview
    composed = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: composed,
    );
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(key: _editKey, child: composed),
    );
  }

  Future<Uint8List?> _renderEditedImageBytes() async {
    try {
      final obj = _editKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) return null;
      final ui.Image image = await obj.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _publish() async {
    if (_origImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Додайте фото')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Try to render the edited composition. Fallback to original if needed.
      Uint8List? finalImage = await _renderEditedImageBytes();
      String finalExt = finalImage != null ? 'png' : (_origImageExt ?? 'jpg');
      final uploadedId = await PostService.createPost(
        imageBytes: finalImage ?? _origImage!,
        imageExt: finalExt,
        caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        filterName: _filter,
        musicBytes: _music,
        musicExt: _musicExt,
        tagUserIds: _tagged.map((e) => e['id']!).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(uploadedId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка публікації: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openTagDialog() async {
    final selected = Set<String>.from(_tagged.map((e) => e['id']!));
    await showDialog(
      context: context,
      builder: (ctx) {
        final q = TextEditingController();
        List<Map<String, dynamic>> results = [];
        bool loading = false;
        Future<void> doSearch(StateSetter localSet) async {
          localSet(() => loading = true);
          final data = await ProfileService.searchProfiles(q.text);
          localSet(() {
            results = data;
            loading = false;
          });
        }

        return StatefulBuilder(
          builder: (ctx, localSet) => AlertDialog(
            title: const Text('Позначити акаунт'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: q,
                    decoration: InputDecoration(
                      hintText: '@username або імʼя',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => doSearch(localSet),
                      ),
                    ),
                    onSubmitted: (_) => doSearch(localSet),
                  ),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(minHeight: 2),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final r = results[i];
                        final id = r['id'] as String;
                        final label = '@${(r['username'] ?? '')}'.toString();
                        final sel = selected.contains(id);
                        return ListTile(
                          dense: true,
                          title: Text(r['display_name'] ?? label),
                          subtitle: Text(label),
                          trailing: sel ? const Icon(Icons.check_circle, color: Colors.green) : null,
                          onTap: () {
                            localSet(() {
                              if (sel) {
                                selected.remove(id);
                              } else {
                                selected.add(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _tagged
                      ..clear()
                      ..addAll(results
                          .where((r) => selected.contains(r['id']))
                          .map((r) => {
                                'id': r['id'] as String,
                                'label': '@${(r['username'] ?? '')}'
                              }));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Готово'),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = ['Виберіть фото', 'Редагування', 'Деталі'];
    return AppBar(
      title: Text(titles[_step]),
      actions: [
        if (_step == 1)
          TextButton(
            onPressed: () => setState(() => _step = 2),
            child: const Text('Далі'),
          ),
        if (_step == 2)
          TextButton(
            onPressed: _saving ? null : _publish,
            child: const Text('Опублікувати'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _step == 0
            ? _buildStepSelect()
            : _step == 1
                ? _buildStepEdit()
                : _buildStepDetails(me?.email),
      ),
    );
  }

  Widget _buildStepSelect() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(
                child: Icon(Icons.add_photo_alternate_outlined, size: 72, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.photo),
              label: const Text('Завантажити фото'),
              onPressed: _pickImage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepEdit() {
    final width = MediaQuery.of(context).size.width;
    final size = width < 380 ? width - 32 : 340.0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(alignment: Alignment.center, child: _buildComposition(size: size)),
        const SizedBox(height: 16),
        Text('Фільтри', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(label: const Text('Без'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
            ChoiceChip(label: const Text('Mono'), selected: _filter == 'mono', onSelected: (_) => setState(() => _filter = 'mono')),
            ChoiceChip(label: const Text('Warm'), selected: _filter == 'warm', onSelected: (_) => setState(() => _filter = 'warm')),
            ChoiceChip(label: const Text('Cool'), selected: _filter == 'cool', onSelected: (_) => setState(() => _filter = 'cool')),
            ChoiceChip(label: const Text('Sepia'), selected: _filter == 'sepia', onSelected: (_) => setState(() => _filter = 'sepia')),
          ],
        ),
        const SizedBox(height: 16),
        Text('Текст на фото', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(hintText: 'Введіть текст…'),
                onChanged: (v) => setState(() => _overlayText = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Row(
                children: [
                  _colorDot(Colors.white),
                  _colorDot(Colors.black),
                  _colorDot(Colors.pinkAccent),
                  _colorDot(Colors.lightBlueAccent),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Розмір'),
            Expanded(
              child: Slider(
                min: 12,
                max: 64,
                value: _overlayFont,
                onChanged: (v) => setState(() => _overlayFont = v),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        Row(
          children: [
            FilledButton.icon(onPressed: _pickMusic, icon: const Icon(Icons.music_note), label: const Text('Додати музику')),
            const SizedBox(width: 12),
            if (_music != null) const Icon(Icons.check_circle, color: Colors.green),
            if (_music != null) const SizedBox(width: 6),
            if (_music != null) const Text('Музику додано'),
            const Spacer(),
            OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Назад'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _origImage == null ? null : () => setState(() => _step = 2),
              child: const Text('Далі'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepDetails(String? email) {
    final width = MediaQuery.of(context).size.width;
    final size = width < 380 ? width - 32 : 340.0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(alignment: Alignment.center, child: _buildComposition(size: size)),
        const SizedBox(height: 12),
        TextField(
          controller: _caption,
          decoration: const InputDecoration(labelText: 'Опис'),
          maxLines: null,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tagged.map((t) => Chip(
                  label: Text(t['label'] ?? ''),
                  onDeleted: () => setState(() => _tagged.remove(t)),
                )),
            ActionChip(
              avatar: const Icon(Icons.alternate_email, size: 18),
              label: const Text('Відмітити акаунт'),
              onPressed: _openTagDialog,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (email != null) Text('Від: $email', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('Назад')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _saving ? null : _publish, child: const Text('Опублікувати')),
          ],
        ),
      ],
    );
  }

  Widget _colorDot(Color c) {
    final sel = _overlayColor.value == c.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkResponse(
        onTap: () => setState(() => _overlayColor = c),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: sel ? Border.all(color: Colors.white, width: 2) : null,
          ),
        ),
      ),
    );
  }
}
