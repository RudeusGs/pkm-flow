import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../pages/domain/page_item.dart';
import '../../pages/presentation/editor_page.dart';
import '../../pages/presentation/pages_controller.dart';
import '../domain/workspace.dart';
import 'workspace_controller.dart';

class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends State<WorkspacesPage> {
  late final PagesController _pagesController;
  final _search = TextEditingController();
  String? _loadedWorkspaceId;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _pagesController = PagesController(
        repository: deps.pageRepository, realtime: deps.realtime);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSelectedPages());
  }

  @override
  void dispose() {
    _search.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _pagesController]),
      builder: (context, _) {
        final workspace = widget.controller.selected;
        _queuePageLoad(workspace);

        if (widget.controller.isLoading &&
            widget.controller.workspaces.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (workspace == null) {
          return EmptyState(
            icon: Icons.space_dashboard_outlined,
            title: 'Chưa có workspace',
            message: 'Tạo workspace để bắt đầu viết page và cộng tác.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await widget.controller.load();
            await _loadSelectedPages(force: true);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _WorkspaceHeader(
                workspace: workspace,
                memberCount: widget.controller.members.length,
                onSwitch: _showWorkspaceSwitcher,
                onSettings: () => _showWorkspaceActions(workspace),
              ),
              const SizedBox(height: 14),
              _ActionStrip(
                onNewPage: _createPage,
                onMembers: _showMembers,
                onInvite: workspace.canManageMembers ? _inviteMember : null,
                onRefresh: () => _loadSelectedPages(force: true),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm page trong workspace'),
                onSubmitted: (_) => _loadSelectedPages(force: true),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                      child: Text('Pages',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900))),
                  Text('${_pagesController.pages.length}',
                      style: const TextStyle(color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 8),
              if (_pagesController.isLoading && _pagesController.pages.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_pagesController.pages.isEmpty)
                const EmptyState(
                    icon: Icons.description_outlined, title: 'Chưa có page')
              else
                ..._pagesController.pages.map(
                  (page) => _PageRow(
                    page: page,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => EditorPage(
                              controller: _pagesController, page: page)),
                    ),
                    onRename: () => _renamePage(page),
                    onDuplicate: () => _pagesController.duplicatePage(page),
                    onDelete: () => _deletePage(page),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _queuePageLoad(Workspace? workspace) {
    if (workspace == null || _loadedWorkspaceId == workspace.id) {
      return;
    }
    _loadedWorkspaceId = workspace.id;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadSelectedPages(force: true));
  }

  Future<void> _loadSelectedPages({bool force = false}) async {
    final workspace = widget.controller.selected;
    if (workspace == null) {
      return;
    }
    if (!force &&
        _loadedWorkspaceId == workspace.id &&
        _pagesController.pages.isNotEmpty) {
      return;
    }
    _loadedWorkspaceId = workspace.id;
    await _pagesController.loadPages(workspace.id,
        keyword: _search.text.trim());
  }

  Future<void> _createPage() async {
    final title = await _askText(context, title: 'Tạo page', label: 'Tên page');
    if (title == null || title.trim().isEmpty) {
      return;
    }
    await _pagesController.createPage(title.trim());
  }

  Future<void> _renamePage(PageItem page) async {
    final title = await _askText(context,
        title: 'Đổi tên page', label: 'Tên page', initial: page.title);
    if (title == null || title.trim().isEmpty) {
      return;
    }
    await _pagesController.renamePage(page, title.trim());
  }

  Future<void> _deletePage(PageItem page) async {
    final ok = await _confirm(context, title: 'Xóa page?', message: page.title);
    if (ok) {
      await _pagesController.deletePage(page);
    }
  }

  Future<void> _showWorkspaceSwitcher() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            const Text('Workspace',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...widget.controller.workspaces.map(
              (workspace) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    backgroundColor: AppColors.soft,
                    child: Text(workspace.name.characters.first.toUpperCase())),
                title: Text(workspace.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    '${workspace.visibility} • ${workspace.currentUserRole}'),
                trailing: widget.controller.selected?.id == workspace.id
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await widget.controller.select(workspace);
                },
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add),
              title: const Text('Tạo workspace'),
              onTap: () async {
                Navigator.pop(context);
                await _createWorkspace();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWorkspaceActions(Workspace workspace) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Sửa workspace'),
              onTap: () async {
                Navigator.pop(context);
                await _editWorkspace(workspace);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Thành viên'),
              onTap: () {
                Navigator.pop(context);
                _showMembers();
              },
            ),
            if (workspace.canManageMembers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt),
                title: const Text('Mời bằng email'),
                onTap: () {
                  Navigator.pop(context);
                  _inviteMember();
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text('Rời workspace'),
              onTap: () async {
                Navigator.pop(context);
                if (await _confirm(context,
                    title: 'Rời workspace?', message: workspace.name)) {
                  await widget.controller.leaveSelected();
                }
              },
            ),
            if (workspace.currentUserRole == 'owner')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Xóa workspace',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  if (await _confirm(context,
                      title: 'Xóa workspace?', message: workspace.name)) {
                    await widget.controller.deleteSelected();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMembers() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Thành viên',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900))),
                  if (widget.controller.selected?.canManageMembers == true)
                    IconButton.filledTonal(
                        onPressed: _inviteMember,
                        icon: const Icon(Icons.person_add_alt)),
                ],
              ),
              const SizedBox(height: 8),
              ...widget.controller.members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      backgroundColor: AppColors.soft,
                      child:
                          Text(member.fullName.characters.first.toUpperCase())),
                  title: Text(member.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('@${member.userName} • ${member.role}'),
                  trailing:
                      widget.controller.selected?.canManageMembers == true &&
                              !member.isOwner
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'remove') {
                                  widget.controller.removeMember(member);
                                } else {
                                  widget.controller.changeRole(member, value);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'manager', child: Text('Manager')),
                                PopupMenuItem(
                                    value: 'member', child: Text('Member')),
                                PopupMenuItem(
                                    value: 'viewer', child: Text('Viewer')),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Xóa khỏi workspace')),
                              ],
                            )
                          : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createWorkspace() async {
    final result = await _showWorkspaceDialog(context);
    if (result != null) {
      await widget.controller.create(result.name,
          description: result.description, visibility: result.visibility);
    }
  }

  Future<void> _editWorkspace(Workspace workspace) async {
    final result = await _showWorkspaceDialog(context, workspace: workspace);
    if (result != null) {
      await widget.controller.updateSelected(
        name: result.name,
        description: result.description,
        visibility: result.visibility,
      );
    }
  }

  Future<void> _inviteMember() async {
    final result = await _showInviteDialog(context);
    if (result != null) {
      await widget.controller
          .inviteMember(email: result.email, role: result.role);
    }
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.workspace,
    required this.memberCount,
    required this.onSwitch,
    required this.onSettings,
  });

  final Workspace workspace;
  final int memberCount;
  final VoidCallback onSwitch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSwitch,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.soft,
                child: Text(workspace.name.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900)),
                    Text('$memberCount thành viên • ${workspace.visibility}',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: onSettings, icon: const Icon(Icons.more_horiz)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.onNewPage,
    required this.onMembers,
    required this.onRefresh,
    this.onInvite,
  });

  final VoidCallback onNewPage;
  final VoidCallback onMembers;
  final VoidCallback onRefresh;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _ActionButton(
                icon: Icons.note_add_outlined,
                label: 'Page',
                onTap: onNewPage)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: Icons.people_alt_outlined,
                label: 'Members',
                onTap: onMembers)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: Icons.person_add_alt, label: 'Invite', onTap: onInvite)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: Icons.sync, label: 'Sync', onTap: onRefresh)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.page,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final PageItem page;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onTap: onTap,
      leading: Text(page.icon ?? '📝', style: const TextStyle(fontSize: 22)),
      title: Text(page.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('Revision ${page.currentRevision}',
          style: const TextStyle(color: AppColors.muted)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'rename':
              onRename();
              break;
            case 'duplicate':
              onDuplicate();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
          PopupMenuItem(value: 'duplicate', child: Text('Nhân bản')),
          PopupMenuItem(value: 'delete', child: Text('Xóa')),
        ],
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

class _InviteResult {
  const _InviteResult({required this.email, required this.role});

  final String email;
  final String role;
}

Future<String?> _askText(BuildContext context,
    {required String title, required String label, String? initial}) {
  final input = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Lưu')),
      ],
    ),
  );
}

Future<bool> _confirm(BuildContext context,
    {required String title, required String message}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK')),
          ],
        ),
      ) ??
      false;
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
        content: SingleChildScrollView(
          child: Column(
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
