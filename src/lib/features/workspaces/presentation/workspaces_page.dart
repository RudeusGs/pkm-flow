import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/workspace.dart';
import 'workspace_controller.dart';

class WorkspacesPage extends StatelessWidget {
  const WorkspacesPage({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Workspaces')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreate(context),
            icon: const Icon(Icons.add),
            label: const Text('Tạo'),
          ),
          body: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.workspaces.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _WorkspaceCard(
                workspace: controller.workspaces[index],
                selected: controller.selected?.id == controller.workspaces[index].id,
                onTap: () => controller.select(controller.workspaces[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreate(BuildContext context) async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo workspace'),
        content: TextField(controller: input, autofocus: true, decoration: const InputDecoration(labelText: 'Tên workspace')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()), child: const Text('Tạo')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await controller.create(name);
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.workspace, required this.selected, required this.onTap});

  final Workspace workspace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: AppColors.soft, child: Text(workspace.name.characters.first.toUpperCase())),
        title: Text(workspace.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(workspace.description?.isNotEmpty == true ? workspace.description! : '${workspace.visibility} • ${workspace.currentUserRole}'),
        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.accent) : const Icon(Icons.chevron_right),
      ),
    );
  }
}
