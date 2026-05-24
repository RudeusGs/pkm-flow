import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/inbox_models.dart';
import 'chat_page.dart';
import 'inbox_controller.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({
    super.key,
    required this.controller,
    required this.workspaces,
  });

  final InboxController controller;
  final List<Workspace> workspaces;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const Text('Messages',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Chat riêng, chia sẻ workspace, và realtime typing.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              if (controller.conversations.isEmpty)
                const EmptyState(
                    icon: Icons.chat_bubble_outline, title: 'Chưa có hội thoại')
              else
                ...controller.conversations.map(
                  (item) => _ConversationTile(
                    conversation: item,
                    onTap: () async {
                      await controller.openConversation(item);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                              controller: controller, workspaces: workspaces),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.soft,
          child:
              Text(conversation.otherFullName.characters.first.toUpperCase()),
        ),
        title: Text(conversation.otherFullName,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          conversation.lastMessagePreview ??
              shortDate(conversation.lastMessageAtUtc),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: conversation.unreadCount > 0
            ? Badge(label: Text('${conversation.unreadCount}'))
            : const Icon(Icons.chevron_right, color: AppColors.muted),
      ),
    );
  }
}
