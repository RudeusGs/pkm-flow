import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/realtime_status_chip.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../inbox/presentation/inbox_page.dart';
import '../../pages/presentation/pages_page.dart';
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
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _workspaceController = WorkspaceController(
        repository: deps.workspaceRepository, realtime: deps.realtime)
      ..load();
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.read(context);
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_workspaceController, widget.authController, deps.realtime]),
      builder: (context, _) {
        final workspace = _workspaceController.selected;
        final pages = <Widget>[
          PagesPage(workspace: workspace),
          TasksPage(workspace: workspace),
          const InboxPage(),
          const PeoplePage(),
          WorkspacesPage(controller: _workspaceController),
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
              const SizedBox(width: 8)
            ],
          ),
          body: pages[_tab],
          floatingActionButton:
              _tab == 0 ? PagesFab(workspace: workspace) : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description),
                  label: 'Pages'),
              NavigationDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: 'Tasks'),
              NavigationDestination(
                  icon: Icon(Icons.inbox_outlined),
                  selectedIcon: Icon(Icons.inbox),
                  label: 'Inbox'),
              NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: 'People'),
              NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: 'Spaces'),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 34,
                    child: Text((user?.fullName ?? 'U')
                        .characters
                        .first
                        .toUpperCase())),
                const SizedBox(height: 12),
                Text(user?.fullName ?? 'User',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                Text('@${user?.userName ?? ''}',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _editProfile(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa hồ sơ'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                    onPressed: authController.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final input =
        TextEditingController(text: authController.user?.fullName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa hồ sơ'),
        content: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên hiển thị')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await authController.updateProfile(name);
    }
  }
}
