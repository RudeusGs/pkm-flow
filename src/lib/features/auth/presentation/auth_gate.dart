import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../home/presentation/home_shell.dart';
import 'auth_controller.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller =
        AuthController(repository: deps.authRepository, realtime: deps.realtime)
          ..bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isBootstrapping) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!_controller.isAuthenticated) {
          return LoginPage(controller: _controller);
        }
        return HomeShell(authController: _controller);
      },
    );
  }
}
