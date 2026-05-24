import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/inbox_models.dart';
import 'inbox_controller.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final unreadCount =
            controller.notifications.where((item) => !item.isRead).length;
        return IconButton(
          tooltip: 'Thông báo',
          onPressed: () => _showNotifications(context),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_none),
          ),
        );
      },
    );
  }

  Future<void> _showNotifications(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _NotificationSheet(controller: controller),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final height = MediaQuery.sizeOf(context).height * .72;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Thông báo',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: controller.markAllNotificationsRead,
                        icon: const Icon(Icons.done_all),
                        label: const Text('Đã đọc'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: controller.notifications.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có thông báo',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: controller.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) => _NotificationTile(
                            item: controller.notifications[index],
                            onTap: () => controller.markNotificationRead(
                                controller.notifications[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.isRead ? Colors.transparent : AppColors.soft,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          item.isRead ? Icons.notifications_none : Icons.notifications_active,
          color: item.isRead ? AppColors.muted : AppColors.accent,
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            item.message,
            if (item.createdDate != null) shortDate(item.createdDate),
          ].join('\n'),
        ),
        trailing: item.isRead
            ? null
            : const Icon(Icons.circle, size: 9, color: AppColors.accent),
      ),
    );
  }
}
