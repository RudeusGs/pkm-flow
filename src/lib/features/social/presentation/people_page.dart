import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
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
        repository: deps.socialRepository, realtime: deps.realtime)
      ..loadFriends();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm username / tên'),
              onSubmitted: _controller.search,
            ),
            const SizedBox(height: 16),
            if (_controller.results.isNotEmpty) ...[
              const Text('Kết quả tìm kiếm',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ..._controller.results.map((user) => _UserTile(
                  user: user, onAdd: () => _controller.sendRequest(user))),
              const SizedBox(height: 20),
            ],
            if (_controller.incoming.isNotEmpty) ...[
              const Text('Lời mời đến',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ..._controller.incoming.map(
                (request) => _RequestTile(
                  request: request,
                  primaryIcon: Icons.check,
                  primaryAction: () => _controller.accept(request),
                  secondaryIcon: Icons.close,
                  secondaryAction: () => _controller.reject(request),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_controller.outgoing.isNotEmpty) ...[
              const Text('Đã gửi lời mời',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ..._controller.outgoing.map(
                (request) => _RequestTile(
                  request: request,
                  primaryIcon: Icons.undo,
                  primaryAction: () => _controller.cancel(request),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text('Bạn bè',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (_controller.friends.isEmpty)
              const EmptyState(
                  icon: Icons.group_outlined, title: 'Chưa có bạn bè')
            else
              ..._controller.friends.map(
                (friend) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(
                            friend.fullName.characters.first.toUpperCase())),
                    title: Text(friend.fullName),
                    subtitle: Text('@${friend.userName}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                            onPressed: () => _openChat(friend),
                            icon: const Icon(Icons.chat_bubble_outline)),
                        IconButton(
                            onPressed: () => _controller.removeFriend(friend),
                            icon: const Icon(Icons.person_remove_outlined)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openChat(FriendItem friend) async {
    final deps = AppScope.read(context);
    final inbox = InboxController(
        repository: deps.inboxRepository, realtime: deps.realtime);
    await inbox.openDirectConversation(friend.userId);
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatPage(controller: inbox)));
    inbox.dispose();
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onAdd});

  final UserSearchResult user;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = user.friendshipStatus == 'none';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Text(user.fullName.characters.first.toUpperCase())),
        title: Text(user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('@${user.userName} • ${user.friendshipStatus}'),
        trailing: canAdd
            ? IconButton(
                onPressed: onAdd, icon: const Icon(Icons.person_add_alt))
            : null,
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.primaryIcon,
    required this.primaryAction,
    this.secondaryIcon,
    this.secondaryAction,
  });

  final FriendRequestItem request;
  final IconData primaryIcon;
  final VoidCallback primaryAction;
  final IconData? secondaryIcon;
  final VoidCallback? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Text(request.otherFullName.characters.first.toUpperCase())),
        title: Text(request.otherFullName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('@${request.otherUserName} • ${request.status}'),
        trailing: Wrap(
          children: [
            IconButton(onPressed: primaryAction, icon: Icon(primaryIcon)),
            if (secondaryIcon != null && secondaryAction != null)
              IconButton(onPressed: secondaryAction, icon: Icon(secondaryIcon)),
          ],
        ),
      ),
    );
  }
}
