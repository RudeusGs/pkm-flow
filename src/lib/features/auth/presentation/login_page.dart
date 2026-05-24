import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _bg = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF191919);
  static const _surfaceHover = Color(0xFF202020);
  static const _border = Color(0xFF2F2F2F);
  static const _text = Color(0xFFF7F7F5);
  static const _muted = Color(0xFF9B9B9B);
  static const _softMuted = Color(0xFF6F6F6F);
  static const _accent = Color(0xFF8B5CF6);
  static const _danger = Color(0xFFE06C75);

  final _userName = TextEditingController();
  final _password = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    await widget.controller.login(
      _userName.text.trim(),
      _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          surface: _bg,
          primary: _text,
          secondary: _accent,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _text,
          selectionColor: Color(0x33444444),
          selectionHandleColor: _text,
        ),
      ),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final isBusy = widget.controller.isBusy;
          final error = widget.controller.error;

          return Scaffold(
            backgroundColor: _bg,
            body: ColoredBox(
              color: _bg,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 18),
                          const _Logo(),
                          const SizedBox(height: 28),
                          const Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _text,
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Organize your notes, pages, and tasks in one place.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 38),
                          const _FieldLabel('Email or Username'),
                          const SizedBox(height: 8),
                          _DarkInput(
                            controller: _userName,
                            hintText: 'name@example.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          const _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          _DarkInput(
                            controller: _password,
                            hintText: '••••••••',
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!isBusy) _submit();
                            },
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              splashRadius: 18,
                              onPressed: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _muted,
                                size: 20,
                              ),
                            ),
                          ),
                          if (error != null && error.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ErrorBox(message: error),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: isBusy ? null : _submit,
                              style: FilledButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _text,
                                disabledBackgroundColor: _surfaceHover,
                                foregroundColor: _bg,
                                disabledForegroundColor: _softMuted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isBusy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: _bg,
                                      ),
                                    )
                                  : const Text(
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'New to BlockSpace? ',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: isBusy
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RegisterPage(
                                              controller: widget.controller,
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text(
                                  'Create an account',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: _LoginPageState._surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LoginPageState._border),
        ),
        child: const Icon(
          Icons.dashboard_customize_rounded,
          color: _LoginPageState._text,
          size: 28,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _LoginPageState._text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DarkInput extends StatelessWidget {
  const _DarkInput({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      cursorColor: _LoginPageState._text,
      style: const TextStyle(
        color: _LoginPageState._text,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _LoginPageState._softMuted,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: _LoginPageState._surface,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _LoginPageState._border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _LoginPageState._text, width: 1.2),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _LoginPageState._danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LoginPageState._danger.withOpacity(0.28)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: _LoginPageState._danger,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
