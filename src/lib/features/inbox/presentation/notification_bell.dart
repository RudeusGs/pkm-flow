import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../domain/inbox_models.dart';
import 'inbox_controller.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final InboxController _controller;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = InboxController(
        repository: deps.inboxRepository, realtime: deps.realtime)
      ..loadNotifications();
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
        return IconButton(
          tooltip: 'Thông báo',
          onPressed: () => _showNotifications(context),
          icon: Badge(
            isLabelVisible: _controller.unreadNotifications > 0,
            label: Text(_controller.unreadNotifications > 99
                ? '99+'
                : '${_controller.unreadNotifications}'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }

  Future<void> _showNotifications(BuildContext context) async {
    await _controller.loadNotifications(silent: true);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          minChildSize: .42,
          maxChildSize: .92,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: BottomSheetHeader(
                    title: 'Notifications',
                    subtitle: _controller.unreadNotifications > 0
                        ? '${_controller.unreadNotifications} unread'
                        : 'All caught up.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _controller.loadNotifications,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _controller.notifications.isEmpty
                              ? null
                              : () => _controller.markAllNotificationsRead(),
                          icon: const Icon(Icons.done_all_rounded),
                          label: const Text('Mark read'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _controller.isLoading &&
                          _controller.notifications.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _controller.notifications.isEmpty
                          ? const EmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'No notifications')
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                              itemCount: _controller.notifications.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _NotificationCard(
                                item: _controller.notifications[index],
                                onTap: () => _controller.markNotificationRead(
                                    _controller.notifications[index]),
                                onMore: () => _showNotificationActions(
                                    _controller.notifications[index]),
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showNotificationActions(NotificationItem item) async {
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: item.title,
      subtitle: item.message,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotionActionRow(
            icon: item.isRead
                ? Icons.mark_email_unread_outlined
                : Icons.mark_email_read_outlined,
            title: item.isRead ? 'Mark unread' : 'Mark read',
            onTap: () => Navigator.pop(
              context,
              item.isRead ? 'unread' : 'read',
            ),
          ),
          const Divider(height: 18),
          NotionActionRow(
            icon: Icons.delete_outline_rounded,
            title: 'Delete notification',
            danger: true,
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action == 'read') {
      await _controller.markNotificationRead(item);
    } else if (action == 'unread') {
      await _controller.markNotificationUnread(item);
    } else if (action == 'delete') {
      if (!mounted) return;
      final confirmed = await NotionConfirmDialog.show(
        context: context,
        title: 'Delete notification?',
        message: 'This removes it from your notification list.',
        confirmLabel: 'Delete',
        danger: true,
      );
      if (!confirmed) return;
      await _controller.deleteNotification(item);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onMore,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.isRead ? AppColors.hover : AppColors.ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            item.isRead
                ? Icons.notifications_none_rounded
                : Icons.notifications_active_rounded,
            color: item.isRead ? AppColors.muted : AppColors.background,
          ),
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${item.message}${item.createdDate == null ? '' : '\n${shortDate(item.createdDate)}'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.isRead)
              const Icon(Icons.circle, size: 10, color: AppColors.accent),
            IconButton(
              tooltip: 'Notification actions',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
