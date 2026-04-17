import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'features/home/presentation/screens/main_shell_screen.dart';
import 'features/workspace/presentation/screens/page_detail_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Block Based PKM',
      initialRoute: AppRoutes.root,
      routes: {
        AppRoutes.root: (_) => const MainShellScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.pageDetail) {
          final args = settings.arguments as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (_) => PageDetailScreen(
              pageId: args['pageId'] as String,
              title: args['title'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}