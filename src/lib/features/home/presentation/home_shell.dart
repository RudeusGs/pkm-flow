import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../activity_logs/data/activity_log_repository.dart';
import '../../activity_logs/presentation/activity_log_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_page.dart';
import '../../inbox/domain/inbox_models.dart';
import '../../inbox/presentation/inbox_controller.dart';
import '../../inbox/presentation/messages_page.dart';
import '../../inbox/presentation/notification_bell.dart';
import '../../social/domain/social_models.dart';
import '../../social/presentation/people_page.dart';
import '../../tasks/presentation/tasks_page.dart';
import '../../workspaces/domain/workspace.dart';
import '../../workspaces/presentation/workspace_controller.dart';
import '../../workspaces/presentation/workspace_hub_page.dart';
import '../../workspaces/presentation/workspace_trash_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.authController,
    this.invitationToken,
  });

  final AuthController authController;
  final String? invitationToken;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final WorkspaceController _workspaceController;
  int _tab = 0;
  int _workspaceHubVersion = 0;
  bool _handledInvitationToken = false;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _workspaceController = WorkspaceController(
      repository: deps.workspaceRepository,
      realtime: deps.realtime,
    );
    _bootstrapWorkspace();
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_workspaceController, widget.authController]),
      builder: (context, _) {
        final workspace = _workspaceController.selected;
        final pages = <Widget>[
          WorkspaceHubPage(
            key: ValueKey('${workspace?.id ?? 'none'}-$_workspaceHubVersion'),
            workspaceController: _workspaceController,
          ),
          TasksPage(workspace: workspace),
          MessagesPage(onWorkspaceOpened: _openWorkspaceFromMessage),
          PeoplePage(onWorkspaceOpened: _openWorkspaceFromMessage),
          ProfilePage(authController: widget.authController),
        ];

        return NotionScaffold(
          appBar: NotionTopBar(
            title: workspace?.name ?? 'Block Based',
            subtitle: _subtitleForTab(_tab),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: _WorkspaceMark(name: workspace?.name ?? 'B'),
            ),
            onTitleTap: () => setState(() => _tab = 0),
            actions: [
              const NotificationBell(),
              AppIconButton(
                tooltip: 'Workspace menu',
                tone: AppIconButtonTone.ghost,
                onPressed: () => _showWorkspaceMenu(context),
                icon: Icons.more_horiz_rounded,
                size: 42,
              ),
            ],
          ),
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NotionBottomNav(
            selectedIndex: _tab,
            onSelected: (index) => setState(() => _tab = index),
            items: const [
              NotionBottomNavItem(
                label: 'Workspace',
                icon: Icons.space_dashboard_outlined,
                activeIcon: Icons.space_dashboard_rounded,
              ),
              NotionBottomNavItem(
                label: 'Tasks',
                icon: Icons.check_circle_outline_rounded,
                activeIcon: Icons.check_circle_rounded,
              ),
              NotionBottomNavItem(
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
              ),
              NotionBottomNavItem(
                label: 'People',
                icon: Icons.people_alt_outlined,
                activeIcon: Icons.people_alt_rounded,
              ),
              NotionBottomNavItem(
                label: 'Me',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitleForTab(int tab) => switch (tab) {
        0 => 'Pages and workspace',
        1 => 'Tasks',
        2 => 'Chat',
        3 => 'People',
        _ => 'Profile',
      };

  Future<void> _bootstrapWorkspace() async {
    await _workspaceController.load();
    await _acceptPendingInvitation();
  }

  Future<void> _acceptPendingInvitation() async {
    if (_handledInvitationToken) return;
    final token = widget.invitationToken?.trim();
    if (token == null || token.isEmpty) return;

    _handledInvitationToken = true;
    try {
      await _workspaceController.acceptInvitation(token);
      if (!mounted) return;
      AppSnackBar.success(context, 'Đã tham gia workspace.');
      setState(() => _tab = 0);
    } catch (err) {
      if (!mounted) return;
      AppSnackBar.error(context, err);
    }
  }

  Future<void> _openWorkspaceFromMessage(Workspace workspace) async {
    await _workspaceController.openWorkspace(workspace);
    if (!mounted) return;
    setState(() => _tab = 0);
  }

  Future<void> _showWorkspaceMenu(BuildContext context) async {
    final workspace = _workspaceController.selected;
    await NotionBottomSheet.show<void>(
      context: context,
      title: workspace?.name ?? 'Workspace',
      subtitle: 'Simple actions for this space.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (workspace != null && workspace.canManageMembersEffective) ...[
            NotionActionRow(
              icon: Icons.send_outlined,
              title: 'Share workspace via message',
              subtitle: 'Send a workspace card to a chat.',
              onTap: () {
                Navigator.pop(context);
                _showShareWorkspaceMessage(context, workspace);
              },
            ),
            NotionActionRow(
              icon: Icons.alternate_email_rounded,
              title: 'Invite member by email/Gmail',
              subtitle: 'Invite someone with a role.',
              onTap: () {
                Navigator.pop(context);
                _showInviteEmail(context);
              },
            ),
          ],
          if (workspace != null)
            NotionActionRow(
              icon: Icons.settings_outlined,
              title: 'Workspace settings',
              subtitle: workspace.canManageSettingsEffective
                  ? 'Rename and configure visibility.'
                  : 'View workspace info.',
              onTap: () {
                Navigator.pop(context);
                _showWorkspaceSettings(context);
              },
            ),
          if (workspace != null)
            NotionActionRow(
              icon: Icons.groups_2_outlined,
              title: 'Members',
              subtitle: 'View people in this workspace.',
              onTap: () {
                Navigator.pop(context);
                _showMembers(context, workspace);
              },
            ),
          if (workspace != null)
            NotionActionRow(
              icon: Icons.history_rounded,
              title: 'Activity log',
              subtitle: 'See who changed what in this workspace.',
              onTap: () {
                Navigator.pop(context);
                _openActivityLog(context, workspace);
              },
            ),
          if (workspace != null)
            NotionActionRow(
              icon: Icons.delete_outline_rounded,
              title: 'Trash',
              subtitle: 'Restore pages moved to Trash.',
              onTap: () {
                Navigator.pop(context);
                _openWorkspaceTrash(context, workspace);
              },
            ),
          if (workspace != null && workspace.canDeleteWorkspaceEffective)
            NotionActionRow(
              icon: Icons.delete_forever_rounded,
              title: 'Delete workspace',
              subtitle: 'Xóa workspace này.',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteWorkspace(context);
              },
            ),
          NotionActionRow(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 4);
            },
          ),
          const Divider(height: 18),
          NotionActionRow(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'End this session on this device.',
            danger: true,
            onTap: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openActivityLog(
    BuildContext context,
    Workspace workspace,
  ) {
    final deps = AppScope.read(context);
    final repository = ActivityLogRepository(apiClient: deps.apiClient);

    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityLogPage(
          workspace: workspace,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _openWorkspaceTrash(
    BuildContext context,
    Workspace workspace,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkspaceTrashPage(workspace: workspace),
      ),
    );

    if (!mounted || changed != true) return;

    // Ép WorkspaceHubPage reload lại page list sau khi restore trong Trash.
    await _workspaceController.openWorkspace(workspace);
    await _workspaceController.load();
    if (mounted) {
      setState(() {
        _tab = 0;
        _workspaceHubVersion++;
      });
    }
  }

  Future<void> _showInviteEmail(BuildContext context) async {
    final workspace = _workspaceController.selected;
    if (workspace == null) return;

    final email = TextEditingController();
    var role = 'member';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BottomSheetHeader(
                  title: 'Invite by email',
                  subtitle:
                      'Choose a role and send an invite to this workspace.',
                ),
                NotionTextField(
                  controller: email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  labelText: 'Email',
                  hintText: 'name@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NotionPill(
                        label: 'Viewer',
                        selected: role == 'viewer',
                        onTap: () => setSheetState(() => role = 'viewer')),
                    NotionPill(
                        label: 'Member',
                        selected: role == 'member',
                        onTap: () => setSheetState(() => role = 'member')),
                    NotionPill(
                        label: 'Manager',
                        selected: role == 'manager',
                        onTap: () => setSheetState(() => role = 'manager')),
                  ],
                ),
                const SizedBox(height: 18),
                NotionButton(
                  label: 'Send invite',
                  icon: Icons.send_rounded,
                  expanded: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (ok == true && email.text.trim().isNotEmpty) {
      try {
        await _workspaceController.inviteByEmail(
            email: email.text.trim(), role: role);
        if (!context.mounted) return;
        AppSnackBar.success(context, 'Đã gửi lời mời.');
      } catch (err) {
        if (!context.mounted) return;
        AppSnackBar.error(context, _workspaceController.error);
      }
    }
  }

  Future<void> _showShareWorkspaceMessage(
      BuildContext context, Workspace workspace) async {
    final deps = AppScope.read(context);
    final inbox = InboxController(
        repository: deps.inboxRepository, realtime: deps.realtime);
    List<FriendItem> friends = const [];
    var role = 'member';
    String? sendingUserId;

    try {
      final results = await Future.wait([
        deps.socialRepository.friends(),
        inbox.loadConversations(silent: true).then((_) => inbox.conversations),
      ]);
      friends = results[0] as List<FriendItem>;
    } catch (err) {
      inbox.dispose();
      if (!context.mounted) return;
      AppSnackBar.error(context, err);
      return;
    }

    if (!context.mounted) {
      inbox.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedBuilder(
          animation: inbox,
          builder: (context, _) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .72,
            minChildSize: .45,
            maxChildSize: .92,
            builder: (context, scrollController) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: BottomSheetHeader(
                    title: 'Share via message',
                    subtitle: 'Send "${workspace.name}" to a friend.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      NotionPill(
                          label: 'Viewer',
                          selected: role == 'viewer',
                          onTap: () => setSheetState(() => role = 'viewer')),
                      NotionPill(
                          label: 'Member',
                          selected: role == 'member',
                          onTap: () => setSheetState(() => role = 'member')),
                    ],
                  ),
                ),
                Expanded(
                  child: friends.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_alt_outlined,
                          title: 'No friends yet',
                          message:
                              'Add a friend first, then share this workspace by message.',
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemCount: friends.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final isSending = sendingUserId == friend.userId;
                            return NotionListTile(
                              onTap: () async {
                                if (sendingUserId != null) return;
                                setSheetState(
                                    () => sendingUserId = friend.userId);
                                try {
                                  final conversation =
                                      _findConversationWithFriend(
                                            inbox.conversations,
                                            friend.userId,
                                          ) ??
                                          await deps.inboxRepository
                                              .createConversation(
                                                  friend.userId);

                                  await inbox.sendWorkspaceShare(
                                    conversation: conversation,
                                    workspace: workspace,
                                    role: role,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  AppSnackBar.success(
                                    context,
                                    'Đã gửi workspace cho ${friend.fullName}.',
                                  );
                                } catch (err) {
                                  if (!context.mounted) return;
                                  setSheetState(() => sendingUserId = null);
                                  AppSnackBar.error(context, err);
                                }
                              },
                              leading: AppAvatar(
                                name: friend.fullName,
                                imageUrl: friend.avatarUrl,
                                radius: 22,
                              ),
                              title: friend.fullName,
                              subtitle: '@${friend.userName}',
                              trailing: isSending
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.send_rounded,
                                      color: AppColors.muted),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    inbox.dispose();
  }

  Conversation? _findConversationWithFriend(
    List<Conversation> conversations,
    String userId,
  ) {
    final id = userId.trim().toLowerCase();
    for (final conversation in conversations) {
      if (conversation.otherUserId.trim().toLowerCase() == id) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> _showMembers(BuildContext context, Workspace workspace) async {
    await _workspaceController.loadMembers();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AnimatedBuilder(
        animation: _workspaceController,
        builder: (context, _) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          minChildSize: .42,
          maxChildSize: .92,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: BottomSheetHeader(
                  title: 'Members',
                  subtitle: workspace.canManageMembersEffective
                      ? 'Bấm nút 3 chấm cạnh member để đổi quyền hoặc xóa khỏi workspace.'
                      : 'Danh sách thành viên trong workspace.',
                ),
              ),
              if (workspace.canManageMembersEffective)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _MemberPermissionNotice(
                    canManage: true,
                    count: _workspaceController.members.length,
                    workspaceName: workspace.name,
                  ),
                ),
              Expanded(
                child: _workspaceController.members.isEmpty
                    ? const EmptyState(
                        icon: Icons.groups_2_outlined,
                        title: 'No members loaded',
                        message: 'Invite someone when you are ready.',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemCount: _workspaceController.members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final member = _workspaceController.members[index];
                          final canManageMember = workspace.canManageMembersEffective &&
                              !member.isOwner &&
                              !member.isCurrentUser;

                          return _MemberTile(
                            member: member,
                            canManage: canManageMember,
                            roleLabel: member.isOwner
                                ? 'Owner'
                                : _roleLabel(member.role),
                            roleIcon: _roleIcon(member.role),
                            onTap: canManageMember
                                ? () => _showMemberActions(context, member)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMemberActions(
    BuildContext context,
    WorkspaceMember member,
  ) async {
    final currentRole = member.role.toLowerCase();
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: member.fullName,
      subtitle: member.email.isEmpty
          ? 'Đổi quyền member trong workspace'
          : '${member.email} · quyền hiện tại: ${_roleLabel(member.role)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MemberActionHint(),
          const SizedBox(height: 10),
          for (final role in const ['viewer', 'member', 'manager'])
            NotionActionRow(
              icon: _roleIcon(role),
              title: 'Đổi thành ${_roleLabel(role)}',
              subtitle: currentRole == role
                  ? 'Đây là quyền hiện tại của member này.'
                  : _roleDescription(role),
              enabled: currentRole != role && !_workspaceController.isBusy,
              trailing: currentRole == role
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
                  : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              onTap: () => Navigator.pop(context, 'role:$role'),
            ),
          const Divider(height: 18),
          NotionActionRow(
            icon: Icons.remove_circle_outline,
            title: 'Remove from workspace',
            subtitle: 'Kick this member out of the workspace.',
            danger: true,
            enabled: !_workspaceController.isBusy,
            onTap: () => Navigator.pop(context, 'remove'),
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action.startsWith('role:')) {
      final role = action.substring('role:'.length);
      try {
        await _workspaceController.changeRole(member, role);
        await _workspaceController.loadMembers(silent: true);
        if (!context.mounted) return;
        AppSnackBar.success(
          context,
          'Đã đổi ${member.fullName} thành ${_roleLabel(role)}.',
        );
      } catch (err) {
        if (!context.mounted) return;
        AppSnackBar.error(context, _workspaceController.error);
      }
      return;
    }

    if (action == 'remove') {
      final confirmed = await NotionConfirmDialog.show(
        context: context,
        title: 'Remove member?',
        message: '${member.fullName} will lose access to this workspace.',
        confirmLabel: 'Remove',
        danger: true,
      );

      if (!confirmed) return;

      try {
        await _workspaceController.removeMember(member);
        await _workspaceController.loadMembers(silent: true);
        if (!context.mounted) return;
        AppSnackBar.success(context, 'Đã xóa ${member.fullName}.');
      } catch (err) {
        if (!context.mounted) return;
        AppSnackBar.error(context, _workspaceController.error);
      }
    }
  }

  String _roleLabel(String role) => switch (role.toLowerCase()) {
        'owner' => 'Owner',
        'manager' => 'Manager',
        'member' => 'Member',
        'viewer' => 'Viewer',
        _ => role.isEmpty ? 'Member' : role,
      };

  IconData _roleIcon(String role) => switch (role.toLowerCase()) {
        'manager' => Icons.admin_panel_settings,
        'member' => Icons.edit_note_rounded,
        'viewer' => Icons.visibility_outlined,
        _ => Icons.verified_user,
      };

  String _roleDescription(String role) => switch (role.toLowerCase()) {
        'manager' => 'Có thể quản lý member và cấu hình workspace.',
        'member' => 'Có thể tạo/sửa nội dung trong workspace.',
        'viewer' => 'Chỉ xem nội dung, không chỉnh sửa.',
        _ => 'Cập nhật quyền truy cập cho member này.',
      };

  Future<void> _showWorkspaceSettings(BuildContext context) async {
    final workspace = _workspaceController.selected;
    if (workspace == null) return;

    final name = TextEditingController(text: workspace.name);
    final description =
        TextEditingController(text: workspace.description ?? '');
    var visibility =
        workspace.visibility.toLowerCase() == 'public' ? 'public' : 'private';

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BottomSheetHeader(
                title: 'Workspace settings',
                subtitle: workspace.canManageSettingsEffective
                    ? 'Chỉnh tên, mô tả và chế độ hiển thị.'
                    : 'Thông tin workspace.',
              ),
              NotionTextField(
                controller: name,
                labelText: 'Workspace name',
                readOnly: !workspace.canManageSettingsEffective,
              ),
              const SizedBox(height: 10),
              NotionTextField(
                controller: description,
                labelText: 'Description',
                minLines: 2,
                maxLines: 4,
                readOnly: !workspace.canManageSettingsEffective,
              ),
              if (workspace.canManageSettingsEffective) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NotionPill(
                      label: 'Private',
                      icon: Icons.lock_outline_rounded,
                      selected: visibility == 'private',
                      onTap: () => setSheetState(() => visibility = 'private'),
                    ),
                    NotionPill(
                      label: 'Public',
                      icon: Icons.public_rounded,
                      selected: visibility == 'public',
                      onTap: () => setSheetState(() => visibility = 'public'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                NotionButton(
                  label: 'Save changes',
                  icon: Icons.done_rounded,
                  expanded: true,
                  onPressed: () => Navigator.pop(context, 'save'),
                ),
              ],
              if (!workspace.canDeleteWorkspaceEffective) ...[
                const SizedBox(height: 10),
                NotionButton(
                  label: 'Leave workspace',
                  icon: Icons.exit_to_app_rounded,
                  danger: true,
                  expanded: true,
                  onPressed: () => Navigator.pop(context, 'leave'),
                ),
              ],
              if (workspace.canDeleteWorkspaceEffective) ...[
                const SizedBox(height: 10),
                NotionButton(
                  label: 'Delete workspace',
                  icon: Icons.delete_outline_rounded,
                  danger: true,
                  expanded: true,
                  onPressed: () => Navigator.pop(context, 'delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (action == 'save' && name.text.trim().isNotEmpty) {
      try {
        await _workspaceController.updateSelected(
          name: name.text.trim(),
          description: description.text.trim(),
          visibility: visibility,
        );
        if (!context.mounted) return;
        AppSnackBar.success(context, 'Đã lưu workspace.');
      } catch (err) {
        if (!context.mounted) return;
        AppSnackBar.error(context, _workspaceController.error);
      }
      return;
    }

    if (action == 'leave') {
      final confirmed = await NotionConfirmDialog.show(
        context: context,
        title: 'Leave workspace?',
        message: 'You will lose access unless someone invites you again.',
        confirmLabel: 'Leave',
        danger: true,
      );
      if (!confirmed) return;

      try {
        await _workspaceController.leaveSelected();
        if (mounted) setState(() => _tab = 0);
      } catch (err) {
        if (!context.mounted) return;
        AppSnackBar.error(context, _workspaceController.error);
      }
      return;
    }

    if (action == 'delete') {
      await _confirmDeleteWorkspace(context);
    }
  }


  Future<void> _confirmDeleteWorkspace(BuildContext context) async {
    final workspace = _workspaceController.selected;
    if (workspace == null) return;

    if (!workspace.canDeleteWorkspaceEffective) {
      AppSnackBar.error(context, 'Không có quyền thực hiện thao tác này.');
      return;
    }

    final confirmed = await NotionConfirmDialog.show(
      context: context,
      title: 'Delete workspace?',
      message: 'This removes the workspace for everyone. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );

    if (!confirmed) return;

    try {
      await _workspaceController.deleteSelected();
      if (!mounted) return;
      AppSnackBar.success(context, 'Đã xóa workspace.');
      setState(() => _tab = 0);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, _workspaceController.error);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await NotionConfirmDialog.show(
      context: context,
      title: 'Logout?',
      message: 'You can log back in any time.',
      confirmLabel: 'Logout',
      danger: true,
    );
    if (confirmed) await widget.authController.logout();
  }
}

class _MemberPermissionNotice extends StatelessWidget {
  const _MemberPermissionNotice({
    required this.canManage,
    required this.count,
    required this.workspaceName,
  });

  final bool canManage;
  final int count;
  final String workspaceName;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(
              canManage
                  ? Icons.admin_panel_settings_outlined
                  : Icons.lock_outline_rounded,
              color: AppColors.ink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count members · $workspaceName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canManage
                      ? 'Quyền đổi role đang bật. Nút 3 chấm ở từng dòng là chỗ phân lại quyền.'
                      : 'Chỉ Owner/Manager mới được đổi quyền member.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.roleLabel,
    required this.roleIcon,
    this.onTap,
  });

  final WorkspaceMember member;
  final bool canManage;
  final String roleLabel;
  final IconData roleIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (member.userName.isNotEmpty) '@${member.userName}',
      if (member.email.isNotEmpty) member.email,
    ];

    return NotionCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.only(left: 14, right: 4, top: 4, bottom: 4),
        leading: AppAvatar(
          name: member.fullName,
          imageUrl: member.avatarUrl,
          radius: 22,
        ),
        title: Text(
          member.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitleParts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, height: 1.35),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleChip(label: roleLabel, icon: roleIcon),
            const SizedBox(width: 4),
            if (canManage)
              AppIconButton(
                tooltip: 'Đổi quyền member',
                tone: AppIconButtonTone.ghost,
                onPressed: onTap,
                icon: Icons.more_horiz_rounded,
                size: 38,
                iconSize: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberActionHint extends StatelessWidget {
  const _MemberActionHint();

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppColors.ink,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Chọn role mới bên dưới. Owner và chính bạn sẽ không hiện thao tác đổi quyền để tránh tự bóp quyền.',
              style: TextStyle(
                color: AppColors.muted,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMark extends StatelessWidget {
  const _WorkspaceMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = _normalizeInitial(trimmed.isEmpty ? 'B' : trimmed.characters.first);

    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Center(
          child: Text(
            initial,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  String _normalizeInitial(String value) {
    const map = {
      'à': 'A', 'á': 'A', 'ạ': 'A', 'ả': 'A', 'ã': 'A',
      'â': 'A', 'ầ': 'A', 'ấ': 'A', 'ậ': 'A', 'ẩ': 'A', 'ẫ': 'A',
      'ă': 'A', 'ằ': 'A', 'ắ': 'A', 'ặ': 'A', 'ẳ': 'A', 'ẵ': 'A',
      'è': 'E', 'é': 'E', 'ẹ': 'E', 'ẻ': 'E', 'ẽ': 'E',
      'ê': 'E', 'ề': 'E', 'ế': 'E', 'ệ': 'E', 'ể': 'E', 'ễ': 'E',
      'ì': 'I', 'í': 'I', 'ị': 'I', 'ỉ': 'I', 'ĩ': 'I',
      'ò': 'O', 'ó': 'O', 'ọ': 'O', 'ỏ': 'O', 'õ': 'O',
      'ô': 'O', 'ồ': 'O', 'ố': 'O', 'ộ': 'O', 'ổ': 'O', 'ỗ': 'O',
      'ơ': 'O', 'ờ': 'O', 'ớ': 'O', 'ợ': 'O', 'ở': 'O', 'ỡ': 'O',
      'ù': 'U', 'ú': 'U', 'ụ': 'U', 'ủ': 'U', 'ũ': 'U',
      'ư': 'U', 'ừ': 'U', 'ứ': 'U', 'ự': 'U', 'ử': 'U', 'ữ': 'U',
      'ỳ': 'Y', 'ý': 'Y', 'ỵ': 'Y', 'ỷ': 'Y', 'ỹ': 'Y',
      'đ': 'D',
      'À': 'A', 'Á': 'A', 'Ạ': 'A', 'Ả': 'A', 'Ã': 'A',
      'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ậ': 'A', 'Ẩ': 'A', 'Ẫ': 'A',
      'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ặ': 'A', 'Ẳ': 'A', 'Ẵ': 'A',
      'È': 'E', 'É': 'E', 'Ẹ': 'E', 'Ẻ': 'E', 'Ẽ': 'E',
      'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ệ': 'E', 'Ể': 'E', 'Ễ': 'E',
      'Ì': 'I', 'Í': 'I', 'Ị': 'I', 'Ỉ': 'I', 'Ĩ': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ọ': 'O', 'Ỏ': 'O', 'Õ': 'O',
      'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ộ': 'O', 'Ổ': 'O', 'Ỗ': 'O',
      'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ợ': 'O', 'Ở': 'O', 'Ỡ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Ụ': 'U', 'Ủ': 'U', 'Ũ': 'U',
      'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ự': 'U', 'Ử': 'U', 'Ữ': 'U',
      'Ỳ': 'Y', 'Ý': 'Y', 'Ỵ': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y',
      'Đ': 'D',
    };

    return map[value] ?? value.toUpperCase();
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.muted),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}