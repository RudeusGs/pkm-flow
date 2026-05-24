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
          appBar: AppBar(
            title: const Text('Workspaces'),
            actions: [
              IconButton(
                  onPressed: () => controller.loadMembers(),
                  icon: const Icon(Icons.refresh)),
              IconButton(
                  onPressed: () => _showCreate(context),
                  icon: const Icon(Icons.add)),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.selected != null)
                  _SelectedWorkspacePanel(controller: controller),
                const SizedBox(height: 16),
                const Text('Tất cả workspace',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...controller.workspaces.map(
                  (workspace) => _WorkspaceCard(
                    workspace: workspace,
                    selected: controller.selected?.id == workspace.id,
                    onTap: () => controller.select(workspace),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreate(BuildContext context) async {
    final result = await _showWorkspaceDialog(context);
    if (result != null) {
      await controller.create(result.name,
          description: result.description, visibility: result.visibility);
    }
  }
}

class _SelectedWorkspacePanel extends StatelessWidget {
  const _SelectedWorkspacePanel({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final workspace = controller.selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(workspace.name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900))),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editWorkspace(context);
                            break;
                          case 'invite':
                            _invite(context);
                            break;
                          case 'leave':
                            controller.leaveSelected();
                            break;
                          case 'delete':
                            controller.deleteSelected();
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        if (workspace.canManageMembers)
                          const PopupMenuItem(
                              value: 'invite', child: Text('Mời thành viên')),
                        const PopupMenuItem(
                            value: 'leave', child: Text('Rời workspace')),
                        if (workspace.currentUserRole == 'owner')
                          const PopupMenuItem(
                              value: 'delete', child: Text('Xóa workspace')),
                      ],
                    ),
                  ],
                ),
                if (workspace.description?.isNotEmpty == true)
                  Text(workspace.description!,
                      style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  Chip(label: Text(workspace.visibility)),
                  Chip(
                      label: Text(workspace.currentUserRole.isEmpty
                          ? 'member'
                          : workspace.currentUserRole)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
                child: Text('Thành viên',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            if (workspace.canManageMembers)
              IconButton.filledTonal(
                  onPressed: () => _invite(context),
                  icon: const Icon(Icons.person_add_alt)),
          ],
        ),
        const SizedBox(height: 8),
        ...controller.members.map(
          (member) => Card(
            child: ListTile(
              leading: CircleAvatar(
                  child: Text(member.fullName.characters.first.toUpperCase())),
              title: Text(member.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('@${member.userName} • ${member.role}'),
              trailing: workspace.canManageMembers && !member.isOwner
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'remove') {
                          controller.removeMember(member);
                        } else {
                          controller.changeRole(member, value);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'manager', child: Text('Manager')),
                        PopupMenuItem(value: 'member', child: Text('Member')),
                        PopupMenuItem(value: 'viewer', child: Text('Viewer')),
                        PopupMenuDivider(),
                        PopupMenuItem(
                            value: 'remove', child: Text('Xóa khỏi workspace')),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editWorkspace(BuildContext context) async {
    final workspace = controller.selected!;
    final result = await _showWorkspaceDialog(context, workspace: workspace);
    if (result != null) {
      await controller.updateSelected(
          name: result.name,
          description: result.description,
          visibility: result.visibility);
    }
  }

  Future<void> _invite(BuildContext context) async {
    final result = await _showInviteDialog(context);
    if (result != null) {
      await controller.inviteMember(email: result.email, role: result.role);
    }
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard(
      {required this.workspace, required this.selected, required this.onTap});

  final Workspace workspace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Text(workspace.name.characters.first.toUpperCase())),
        title: Text(workspace.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(workspace.description?.isNotEmpty == true
            ? workspace.description!
            : '${workspace.visibility} • ${workspace.currentUserRole}'),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.accent)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _WorkspaceFormResult {
  const _WorkspaceFormResult(
      {required this.name, this.description, required this.visibility});

  final String name;
  final String? description;
  final String visibility;
}

Future<_WorkspaceFormResult?> _showWorkspaceDialog(BuildContext context,
    {Workspace? workspace}) {
  final name = TextEditingController(text: workspace?.name ?? '');
  final description = TextEditingController(text: workspace?.description ?? '');
  var visibility = workspace?.visibility == 'public' ? 'public' : 'private';
  return showDialog<_WorkspaceFormResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(workspace == null ? 'Tạo workspace' : 'Sửa workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên workspace'),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Mô tả')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'private',
                    label: Text('Private'),
                    icon: Icon(Icons.lock_outline)),
                ButtonSegment(
                    value: 'public',
                    label: Text('Public'),
                    icon: Icon(Icons.public)),
              ],
              selected: {visibility},
              onSelectionChanged: (value) =>
                  setState(() => visibility = value.first),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _WorkspaceFormResult(
                        name: name.text.trim(),
                        description: description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        visibility: visibility,
                      ),
                    ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}

class _InviteResult {
  const _InviteResult({required this.email, required this.role});

  final String email;
  final String role;
}

Future<_InviteResult?> _showInviteDialog(BuildContext context) {
  final email = TextEditingController();
  var role = 'member';
  return showDialog<_InviteResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Mời thành viên'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
              onChanged: (value) => setState(() => role = value ?? 'member'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: email.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context,
                    _InviteResult(email: email.text.trim(), role: role)),
            child: const Text('Mời'),
          ),
        ],
      ),
    ),
  );
}
