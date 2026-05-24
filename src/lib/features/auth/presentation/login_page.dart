import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userName = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Block Based',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink)),
                      const SizedBox(height: 8),
                      const Text(
                          'Notion mobile tối giản cho workspace, page, task và realtime.',
                          style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 24),
                      TextField(
                          controller: _userName,
                          decoration:
                              const InputDecoration(labelText: 'Username')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _password,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password')),
                      if (widget.controller.error != null) ...[
                        const SizedBox(height: 12),
                        Text(widget.controller.error!,
                            style: const TextStyle(color: AppColors.danger)),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: widget.controller.isBusy
                            ? null
                            : () => widget.controller
                                .login(_userName.text.trim(), _password.text),
                        child: widget.controller.isBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Đăng nhập'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => RegisterPage(
                                    controller: widget.controller))),
                        child: const Text('Tạo tài khoản mới'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
