import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../inbox/domain/inbox_models.dart';
import '../../inbox/presentation/chat_page.dart';
import '../../inbox/presentation/inbox_controller.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/social_models.dart';
import 'people_controller.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key, this.onWorkspaceOpened});

  final Future<void> Function(Workspace workspace)? onWorkspaceOpened;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  late final PeopleController _controller;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = PeopleController(
      repository: deps.socialRepository,
      realtime: deps.realtime,
    )..loadFriends();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openChat(
    String userId, {
    required String displayName,
    required bool canChat,
  }) async {
    if (!canChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chỉ bạn bè mới nhắn tin riêng được. Hãy kết bạn hoặc chấp nhận lời mời trước.',
          ),
        ),
      );
      return;
    }

    final deps = AppScope.read(context);
    final inbox = InboxController(
      repository: deps.inboxRepository,
      realtime: deps.realtime,
    );

    try {
      // Prefer an existing conversation first. It avoids creating duplicate
      // direct chats and still works if the backend already has a thread.
      await inbox.loadConversations(silent: true);
      final existing = _findConversationWith(inbox.conversations, userId);
      final conversation =
          existing ?? await deps.inboxRepository.createConversation(userId);

      await inbox.openConversation(conversation);
      if (!mounted) {
        inbox.dispose();
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            controller: inbox,
            onWorkspaceOpened: widget.onWorkspaceOpened,
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;

      final message = err.toString().contains('Chỉ bạn bè')
          ? 'Không mở được chat với $displayName vì backend chỉ cho bạn bè nhắn tin riêng. Thử refresh People hoặc kiểm tra hai tài khoản đã là bạn bè thật chưa.'
          : 'Không mở được chat với $displayName: $err';

      await _controller.loadFriends(silent: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      inbox.dispose();
    }
  }

  Conversation? _findConversationWith(List<Conversation> conversations, String userId) {
    final id = userId.trim().toLowerCase();
    for (final conversation in conversations) {
      if (conversation.otherUserId.trim().toLowerCase() == id) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thao tác thất bại: $err')),
      );
    }
  }

  Future<void> _confirmRemoveFriend(FriendItem friend) async {
    final confirmed = await NotionConfirmDialog.show(
      context: context,
      title: 'Remove friend?',
      message: 'You can send a new request later.',
      confirmLabel: 'Remove',
      danger: true,
    );

    if (!confirmed) return;

    await _runAction(
      () => _controller.removeFriend(friend),
      success: 'Removed ${friend.fullName}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: _controller.loadFriends,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              const Text(
                'People',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find people, start chat, and manage friend requests.',
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              NotionTextField(
                controller: _search,
                hintText: 'Search username or name...',
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                suffixIcon: _controller.isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Search',
                        onPressed: () => _controller.search(_search.text),
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                onSubmitted: _controller.search,
              ),
              if (_controller.error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: _controller.error!),
              ],
              if (_controller.incomingRequests.isNotEmpty) ...[
                const SizedBox(height: 18),
                NotionSection(
                  title: 'Friend requests',
                  children: _controller.incomingRequests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FriendRequestTile(
                            request: request,
                            incoming: true,
                            onAccept: () => _runAction(
                              () => _controller.acceptRequest(request),
                              success: 'You are now friends.',
                            ),
                            onReject: () => _runAction(
                              () => _controller.rejectRequest(request),
                              success: 'Request rejected.',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_controller.outgoingRequests.isNotEmpty) ...[
                const SizedBox(height: 18),
                NotionSection(
                  title: 'Sent requests',
                  children: _controller.outgoingRequests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FriendRequestTile(
                            request: request,
                            incoming: false,
                            onCancel: () => _runAction(
                              () => _controller.cancelRequest(request),
                              success: 'Request cancelled.',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_controller.results.isNotEmpty) ...[
                const SizedBox(height: 18),
                NotionSection(
                  title: 'Search results',
                  children: _controller.results
                      .map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UserTile(
                            user: user,
                            effectiveStatus: _controller.effectiveStatus(user),
                            onAdd: () => _runAction(
                              () => _controller.sendRequest(user),
                              success: 'Friend request sent.',
                            ),
                            onChat: () => _openChat(
                              user.id,
                              displayName: user.fullName,
                              canChat: _controller.effectiveStatus(user) == 'friends',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Friends',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_controller.isLoading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_controller.friends.isEmpty)
                const EmptyState(
                  icon: Icons.group_outlined,
                  title: 'No friends yet',
                  message: 'Search for someone and send a friend request.',
                )
              else
                ..._controller.friends.map(
                  (friend) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NotionListTile(
                      onTap: () => _openChat(
                        friend.userId,
                        displayName: friend.fullName,
                        canChat: true,
                      ),
                      leading: AppAvatar(
                        name: friend.fullName,
                        imageUrl: friend.avatarUrl,
                        radius: 23,
                      ),
                      title: friend.fullName,
                      subtitle: [
                        '@${friend.userName}',
                        if (friend.friendsSinceUtc?.isNotEmpty == true)
                          'Friend since ${shortDate(friend.friendsSinceUtc)}',
                      ].join(' · '),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Message',
                            onPressed: () => _openChat(
                              friend.userId,
                              displayName: friend.fullName,
                              canChat: true,
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove friend',
                            onPressed: () => _confirmRemoveFriend(friend),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.effectiveStatus,
    required this.onAdd,
    required this.onChat,
  });

  final UserSearchResult user;
  final String effectiveStatus;
  final VoidCallback onAdd;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return NotionListTile(
      onTap: () => _showActions(context),
      leading: AppAvatar(
        name: user.fullName,
        imageUrl: user.avatarUrl,
        radius: 23,
      ),
      title: user.fullName,
      subtitle: '@${user.userName} · ${_friendshipLabel(effectiveStatus)}',
      trailing: _UserQuickAction(
        status: effectiveStatus,
        onAdd: onAdd,
        onChat: onChat,
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final status = effectiveStatus;
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: user.fullName,
      subtitle: '@${user.userName} · ${_friendshipLabel(status)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'friends')
            NotionActionRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Message',
              onTap: () => Navigator.pop(context, 'chat'),
            ),
          if (status == 'none')
            NotionActionRow(
              icon: Icons.person_add_alt_rounded,
              title: 'Add friend',
              onTap: () => Navigator.pop(context, 'add'),
            ),
          if (status == 'request_sent')
            const NotionActionRow(
              icon: Icons.schedule_rounded,
              title: 'Request sent',
              subtitle: 'You can cancel it from Sent requests.',
              enabled: false,
            ),
          if (status == 'request_received')
            const NotionActionRow(
              icon: Icons.mark_email_unread_outlined,
              title: 'Request received',
              subtitle: 'Accept or reject it from Friend requests.',
              enabled: false,
            ),
          if (status == 'self')
            const NotionActionRow(
              icon: Icons.person_outline_rounded,
              title: 'This is you',
              enabled: false,
            ),
        ],
      ),
    );

    if (action == 'chat') onChat();
    if (action == 'add') onAdd();
  }

  String _friendshipLabel(String value) => switch (value) {
        'friends' => 'Friend',
        'request_sent' => 'Request sent',
        'request_received' => 'Request received',
        'self' => 'You',
        _ => 'Add friend',
      };
}

class _UserQuickAction extends StatelessWidget {
  const _UserQuickAction({
    required this.status,
    required this.onAdd,
    required this.onChat,
  });

  final String status;
  final VoidCallback onAdd;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    if (status == 'friends') {
      return IconButton(
        tooltip: 'Message',
        onPressed: onChat,
        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.muted),
      );
    }

    if (status == 'none') {
      return TextButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.person_add_alt_rounded, size: 17),
        label: const Text('Add'),
      );
    }

    final label = switch (status) {
      'request_sent' => 'Sent',
      'request_received' => 'Request',
      'self' => 'You',
      _ => 'Add',
    };

    return _StatusBadge(label: label);
  }
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.request,
    required this.incoming,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  final FriendRequestItem request;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final user = request.otherUser;
    return NotionListTile(
      leading: AppAvatar(
        name: user.fullName,
        imageUrl: user.avatarUrl,
        radius: 23,
      ),
      title: user.fullName,
      subtitle: [
        '@${user.userName}',
        incoming ? 'Wants to connect' : 'Waiting for reply',
      ].join(' · '),
      trailing: incoming
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Reject',
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                ),
                IconButton(
                  tooltip: 'Accept',
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded, color: AppColors.ink),
                ),
              ],
            )
          : TextButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(9),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
