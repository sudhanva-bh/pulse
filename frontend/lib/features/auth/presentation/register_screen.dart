import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';

import 'widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _localError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Client-side validation before hitting the network
    if (_passwordController.text != _confirmController.text) {
      setState(() => _localError = "Passwords don't match");
      return;
    }
    setState(() => _localError = null);

    await ref
        .read(authProvider.notifier)
        .register(_usernameController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;
    final serverError = authState is AuthError ? authState.message : null;
    final displayError = _localError ?? serverError;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Logo(subtitle: 'Join Pulse'),
              const SizedBox(height: 32),
              if (displayError != null) ErrorChip(message: displayError),
              UsernameField(
                controller: _usernameController,
                hint: 'Letters and numbers only, no spaces',
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordController,
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmController,
                label: 'Confirm password',
                placeholder: 'Repeat your password',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 16),
              FooterLink(
                label: "Already have one?",
                action: "Sign in",
                onTap: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
