import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/inbox_models.dart';
import 'chat_page.dart';
import 'inbox_controller.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final InboxController _controller;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = InboxController(
        repository: deps.inboxRepository, realtime: deps.realtime)
      ..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Thông báo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: _controller.markAllNotificationsRead,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Đã đọc hết')),
              ),
              const SizedBox(height: 8),
              if (_controller.notifications.isEmpty)
                const EmptyState(
                    icon: Icons.notifications_none, title: 'Chưa có thông báo')
              else
                ..._controller.notifications.take(10).map(
                      (item) => Card(
                        child: ListTile(
                          onTap: () => _controller.markNotificationRead(item),
                          leading: Icon(
                              item.isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                              color: item.isRead
                                  ? AppColors.muted
                                  : AppColors.accent),
                          title: Text(item.title),
                          subtitle: Text(item.message),
                          trailing: item.isRead
                              ? null
                              : const Icon(Icons.circle,
                                  size: 10, color: AppColors.accent),
                        ),
                      ),
                    ),
              const SizedBox(height: 22),
              const Text('Tin nhắn',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (_controller.conversations.isEmpty)
                const EmptyState(
                    icon: Icons.chat_bubble_outline, title: 'Chưa có hội thoại')
              else
                ..._controller.conversations.map((item) => _ConversationTile(
                    conversation: item,
                    onTap: () async {
                      await _controller.openConversation(item);
                      if (!context.mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatPage(controller: _controller)));
                    })),
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
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
            child: Text(
                conversation.otherFullName.characters.first.toUpperCase())),
        title: Text(conversation.otherFullName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(conversation.lastMessagePreview ??
            shortDate(conversation.lastMessageAtUtc)),
        trailing: conversation.unreadCount > 0
            ? Badge(label: Text('${conversation.unreadCount}'))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
