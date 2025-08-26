import 'package:flutter/material.dart';
// ignore_for_file: unused_import
import 'create_post_page.dart';
import 'post_wizard_page.dart';

class AddPostPage extends StatelessWidget {
  const AddPostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Створити пост'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostWizardPage()),
        ),
      ),
    );
  }
}
