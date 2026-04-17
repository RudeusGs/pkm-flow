import 'package:flutter/material.dart';
import '../../../../core/routes/app_routes.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      {'id': '1', 'title': 'Daily Notes'},
      {'id': '2', 'title': 'Project Ideas'},
      {'id': '3', 'title': 'Meeting Notes'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace'),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];

          return ListTile(
            leading: const Icon(Icons.note_alt_outlined),
            title: Text(page['title']!),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.pageDetail,
                arguments: {
                  'pageId': page['id'],
                  'title': page['title'],
                },
              );
            },
          );
        },
      ),
    );
  }
}