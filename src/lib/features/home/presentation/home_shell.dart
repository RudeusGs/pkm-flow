import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/realtime_status_chip.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../inbox/presentation/inbox_controller.dart';
import '../../inbox/presentation/messages_page.dart';
import '../../inbox/presentation/notification_bell.dart';
import '../../social/presentation/people_page.dart';
import '../../tasks/presentation/tasks_page.dart';
import '../../workspaces/presentation/workspace_controller.dart';
import '../../workspaces/presentation/workspaces_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.authController});

  final AuthController authController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final WorkspaceController _workspaceController;
  late final InboxController _inboxController;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _workspaceController = WorkspaceController(
        repository: deps.workspaceRepository, realtime: deps.realtime)
      ..load();
    _inboxController = InboxController(
        repository: deps.inboxRepository, realtime: deps.realtime)
      ..load();
  }

  @override
  void dispose() {
    _inboxController.dispose();
    _workspaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.read(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        _workspaceController,
        _inboxController,
        widget.authController,
        deps.realtime
      ]),
      builder: (context, _) {
        final workspace = _workspaceController.selected;
        final pages = <Widget>[
          WorkspacesPage(controller: _workspaceController),
          TasksPage(workspace: workspace),
          MessagesPage(
              controller: _inboxController,
              workspaces: _workspaceController.workspaces),
          const PeoplePage(),
          _ProfilePage(authController: widget.authController),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workspace?.name ?? 'Block Based',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.authController.user?.fullName ?? '',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
            actions: [
              RealtimeStatusChip(realtime: deps.realtime),
              NotificationBell(controller: _inboxController),
              const SizedBox(width: 8)
            ],
          ),
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: 'Workspace'),
              NavigationDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: 'Tasks'),
              NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Messages'),
              NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: 'People'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Me'),
            ],
          ),
        );
      },
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.authController});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final user = authController.user;
    final avatarUrl = user?.avatarUrl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: avatarUrl == null || avatarUrl.trim().isEmpty
                      ? null
                      : NetworkImage(avatarUrl),
                  child: avatarUrl == null || avatarUrl.trim().isEmpty
                      ? Text((user?.fullName ?? 'U')
                          .characters
                          .first
                          .toUpperCase())
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('@${user?.userName ?? ''}',
                          style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Sửa hồ sơ'),
          subtitle: const Text('Tên hiển thị và avatar URL'),
          onTap: () => _editProfile(context),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Đăng xuất'),
          onTap: authController.logout,
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final nameInput =
        TextEditingController(text: authController.user?.fullName ?? '');
    final avatarInput =
        TextEditingController(text: authController.user?.avatarUrl ?? '');
    final result = await showDialog<({String fullName, String? avatarUrl})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameInput,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên hiển thị')),
            const SizedBox(height: 12),
            TextField(
                controller: avatarInput,
                decoration:
                    const InputDecoration(labelText: 'Avatar image URL')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(
                    context,
                    (
                      fullName: nameInput.text.trim(),
                      avatarUrl: avatarInput.text.trim().isEmpty
                          ? null
                          : avatarInput.text.trim(),
                    ),
                  ),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (result != null && result.fullName.isNotEmpty) {
      await authController.updateProfile(
        result.fullName,
        avatarUrl: result.avatarUrl,
      );
    }
  }
}
