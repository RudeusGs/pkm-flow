import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _userName.dispose();
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.controller.register(
      userName: _userName.text.trim(),
      email: _email.text.trim(),
      fullName: _fullName.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tạo tài khoản xong, đăng nhập tiếp nha.')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
              controller: _userName,
              decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password')),
          if (widget.controller.error != null) ...[
            const SizedBox(height: 12),
            Text(widget.controller.error!,
                style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          FilledButton(
              onPressed: widget.controller.isBusy ? null : _submit,
              child: const Text('Tạo tài khoản')),
        ],
      ),
    );
  }
}
