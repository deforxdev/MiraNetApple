import 'package:flutter/material.dart';

class EmailConfirmationPage extends StatelessWidget {
  final String email;
  const EmailConfirmationPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Підтвердження пошти')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Ми надіслали лист для підтвердження на:\n$email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Перейдіть за посиланням у листі, щоб активувати аккаунт. Після цього поверніться до входу.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text('Перейти до входу'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
