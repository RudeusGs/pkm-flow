import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
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
          WorkspaceHubPage(workspaceController: _workspaceController),
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
              IconButton(
                tooltip: 'Workspace menu',
                onPressed: () => _showWorkspaceMenu(context),
                icon: const Icon(Icons.more_horiz_rounded),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace invitation accepted.')),
      );
      setState(() => _tab = 0);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept invitation: $err')),
      );
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
          NotionActionRow(
            icon: Icons.send_outlined,
            title: 'Share workspace via message',
            subtitle: workspace == null
                ? 'Create a workspace first.'
                : 'Send a workspace card to a chat.',
            enabled: workspace != null,
            onTap: () {
              Navigator.pop(context);
              _showShareWorkspaceMessage(context, workspace!);
            },
          ),
          NotionActionRow(
            icon: Icons.alternate_email_rounded,
            title: 'Invite member by email/Gmail',
            subtitle: workspace == null
                ? 'Create a workspace first.'
                : 'Invite someone with a role.',
            enabled: workspace != null,
            onTap: () {
              Navigator.pop(context);
              _showInviteEmail(context);
            },
          ),
          NotionActionRow(
            icon: Icons.settings_outlined,
            title: 'Workspace settings',
            enabled: workspace != null,
            onTap: () {
              Navigator.pop(context);
              _showWorkspaceSettings(context);
            },
          ),
          NotionActionRow(
            icon: Icons.groups_2_outlined,
            title: 'Members',
            enabled: workspace != null,
            onTap: () {
              Navigator.pop(context);
              if (workspace != null) _showMembers(context, workspace);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite email sent.')),
        );
      } catch (err) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send invite: $err')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load friends: $err')),
      );
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Workspace shared with ${friend.fullName}.'),
                                    ),
                                  );
                                } catch (err) {
                                  if (!context.mounted) return;
                                  setSheetState(() => sendingUserId = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Could not share with ${friend.fullName}: $err'),
                                    ),
                                  );
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
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .65,
        minChildSize: .35,
        maxChildSize: .9,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: BottomSheetHeader(
                title: 'Members',
                subtitle:
                    '${_workspaceController.members.length} people in ${workspace.name}',
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
                        final canManageMember = workspace.canManageMembers &&
                            !member.isOwner &&
                            !member.isCurrentUser;

                        return NotionListTile(
                          onTap: canManageMember
                              ? () => _showMemberActions(context, member)
                              : null,
                          leading: AppAvatar(
                            name: member.fullName,
                            imageUrl: member.avatarUrl,
                            radius: 22,
                          ),
                          title: member.fullName,
                          subtitle: [
                            if (member.userName.isNotEmpty)
                              '@${member.userName}',
                            if (member.email.isNotEmpty) member.email,
                          ].join(' · '),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RoleChip(
                                label: member.isOwner
                                    ? 'Owner'
                                    : _roleLabel(member.role),
                              ),
                              if (canManageMember) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppColors.muted,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMemberActions(
    BuildContext context,
    WorkspaceMember member,
  ) async {
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: member.fullName,
      subtitle: member.email.isEmpty ? 'Member actions' : member.email,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in const ['viewer', 'member', 'manager'])
            NotionActionRow(
              icon: _roleIcon(role),
              title: _roleLabel(role),
              subtitle: member.role.toLowerCase() == role
                  ? 'Current role'
                  : 'Change role to ${_roleLabel(role).toLowerCase()}',
              enabled: member.role.toLowerCase() != role,
              trailing: member.role.toLowerCase() == role
                  ? const Icon(Icons.check_rounded, color: AppColors.ink)
                  : null,
              onTap: () => Navigator.pop(context, 'role:$role'),
            ),
          const Divider(height: 18),
          NotionActionRow(
            icon: Icons.remove_circle_outline,
            title: 'Remove from workspace',
            subtitle: 'Kick this member out of the workspace.',
            danger: true,
            onTap: () => Navigator.pop(context, 'remove'),
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action.startsWith('role:')) {
      final role = action.substring('role:'.length);
      await _workspaceController.changeRole(member, role);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Changed ${member.fullName} to ${_roleLabel(role)}.')),
      );
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

      await _workspaceController.removeMember(member);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${member.fullName}.')),
      );
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
              const BottomSheetHeader(title: 'Workspace settings'),
              NotionTextField(controller: name, labelText: 'Workspace name'),
              const SizedBox(height: 10),
              NotionTextField(
                controller: description,
                labelText: 'Description',
                minLines: 2,
                maxLines: 4,
              ),
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
              const SizedBox(height: 10),
              NotionButton(
                label: 'Leave workspace',
                icon: Icons.exit_to_app_rounded,
                danger: true,
                expanded: true,
                onPressed: () => Navigator.pop(context, 'leave'),
              ),
              if (workspace.canManageMembers) ...[
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
      await _workspaceController.updateSelected(
        name: name.text.trim(),
        description: description.text.trim(),
        visibility: visibility,
      );
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
      if (confirmed) await _workspaceController.leaveSelected();
      return;
    }

    if (action == 'delete') {
      final confirmed = await NotionConfirmDialog.show(
        context: context,
        title: 'Delete workspace?',
        message:
            'This removes the workspace for everyone. This cannot be undone.',
        confirmLabel: 'Delete',
        danger: true,
      );
      if (confirmed) await _workspaceController.deleteSelected();
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

class _WorkspaceMark extends StatelessWidget {
  const _WorkspaceMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? 'B' : trimmed.characters.first.toUpperCase();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

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
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
