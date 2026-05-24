import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../inbox/presentation/chat_page.dart';
import '../../inbox/presentation/inbox_controller.dart';
import '../domain/social_models.dart';
import 'people_controller.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

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

  Future<void> _openChat(String userId) async {
    final deps = AppScope.read(context);
    final inbox = InboxController(
        repository: deps.inboxRepository, realtime: deps.realtime);
    final conversation = await deps.inboxRepository.createConversation(userId);
    await inbox.openConversation(conversation);
    if (!mounted) {
      inbox.dispose();
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatPage(controller: inbox)));
    inbox.dispose();
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
                'Find people, start chat, and share workspaces.',
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              NotionTextField(
                controller: _search,
                hintText: 'Search username or name...',
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: () => _controller.search(_search.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                onSubmitted: _controller.search,
              ),
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
                            onAdd: () => _controller.sendRequest(user),
                            onChat: () => _openChat(user.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Friends',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900),
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
                      leading: AppAvatar(
                          name: friend.fullName,
                          imageUrl: friend.avatarUrl,
                          radius: 23),
                      title: friend.fullName,
                      subtitle: '@${friend.userName} · Friend',
                      trailing: IconButton(
                        tooltip: 'Message',
                        onPressed: () => _openChat(friend.userId),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: AppColors.muted),
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
    required this.onAdd,
    required this.onChat,
  });

  final UserSearchResult user;
  final VoidCallback onAdd;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return NotionListTile(
      onTap: () => _showActions(context),
      leading:
          AppAvatar(name: user.fullName, imageUrl: user.avatarUrl, radius: 23),
      title: user.fullName,
      subtitle:
          '@${user.userName} · ${_friendshipLabel(user.friendshipStatus)}',
      trailing: _FriendshipBadge(status: user.friendshipStatus),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final canAdd = user.friendshipStatus == 'none';
    final canChat = user.friendshipStatus == 'friends' ||
        user.friendshipStatus == 'self' ||
        !canAdd;
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: user.fullName,
      subtitle:
          '@${user.userName} · ${_friendshipLabel(user.friendshipStatus)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canChat && user.friendshipStatus != 'self')
            NotionActionRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Message',
              onTap: () => Navigator.pop(context, 'chat'),
            ),
          if (canAdd)
            NotionActionRow(
              icon: Icons.person_add_alt_rounded,
              title: 'Add friend',
              onTap: () => Navigator.pop(context, 'add'),
            ),
          if (user.friendshipStatus == 'request_sent')
            const NotionActionRow(
              icon: Icons.schedule_rounded,
              title: 'Request sent',
              subtitle: 'Waiting for the other person.',
              enabled: false,
            ),
          if (user.friendshipStatus == 'request_received')
            const NotionActionRow(
              icon: Icons.mark_email_unread_outlined,
              title: 'Request received',
              subtitle:
                  'Accept/reject endpoints are not available in this client yet.',
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

class _FriendshipBadge extends StatelessWidget {
  const _FriendshipBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'friends' => 'Friend',
      'request_sent' => 'Sent',
      'request_received' => 'Received',
      'self' => 'You',
      _ => 'Add',
    };
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
            color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}
