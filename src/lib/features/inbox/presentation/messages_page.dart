import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/inbox_models.dart';
import 'chat_page.dart';
import 'inbox_controller.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.onWorkspaceOpened});

  final Future<void> Function(Workspace workspace)? onWorkspaceOpened;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late final InboxController _controller;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = InboxController(
      repository: deps.inboxRepository,
      realtime: deps.realtime,
    )..loadConversations();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openConversation(Conversation conversation) async {
    await _controller.openConversation(conversation);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          controller: _controller,
          onWorkspaceOpened: widget.onWorkspaceOpened,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final conversations = query.isEmpty
            ? _controller.conversations
            : _controller.conversations.where((item) {
                return item.otherFullName.toLowerCase().contains(query) ||
                    item.otherUserName.toLowerCase().contains(query) ||
                    (item.lastMessagePreview ?? '')
                        .toLowerCase()
                        .contains(query);
              }).toList();

        if (_controller.isLoading && _controller.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _controller.loadConversations,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chat',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 30,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Messages and workspace share cards live here.',
                        style: TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      NotionTextField(
                        controller: _search,
                        hintText: 'Search conversations...',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
              if (conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: query.isEmpty ? 'No conversations yet' : 'No chat found',
                    message: query.isEmpty
                        ? 'Find someone in People and start a conversation.'
                        : 'Try another name or message.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, rawIndex) {
                        if (rawIndex.isOdd) return const SizedBox(height: 10);
                        final index = rawIndex ~/ 2;
                        final conversation = conversations[index];
                        return _ConversationCard(
                          conversation: conversation,
                          onTap: () => _openConversation(conversation),
                        );
                      },
                      childCount: conversations.length * 2 - 1,
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

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = conversation.lastMessagePreview?.trim();
    final time = shortDate(conversation.lastMessageAtUtc);
    return NotionCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: AppAvatar(
          name: conversation.otherFullName,
          imageUrl: conversation.otherAvatarUrl,
          radius: 24,
        ),
        title: Text(
          conversation.otherFullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          preview?.isNotEmpty == true ? preview! : 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (conversation.unreadCount > 0)
              Badge(label: Text('${conversation.unreadCount}'))
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
