import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate.dart';
import '../core/theme/app_theme.dart';

class BlockBasedApp extends StatelessWidget {
  const BlockBasedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Block Based PKM',
      theme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}
