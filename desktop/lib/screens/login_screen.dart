import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

import '../theme/desk_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobile = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authProvider.notifier)
        .login(_mobile.text.trim(), _password.text);
    if (mounted &&
        ref.read(authProvider).hasValue &&
        ref.read(authProvider).value != null) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    size: 40,
                    color: DeskColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kansjor Borewell',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Back-office workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _mobile,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (auth.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        apiErrorMessage(auth.error!),
                        style: const TextStyle(color: DeskColors.danger),
                      ),
                    ),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: Text(auth.isLoading ? 'Signing in...' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
