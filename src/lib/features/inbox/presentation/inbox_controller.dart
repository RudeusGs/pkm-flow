import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/inbox_repository.dart';
import '../domain/inbox_models.dart';

class InboxController extends ChangeNotifier {
  InboxController(
      {required InboxRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final InboxRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  List<NotificationItem> notifications = const [];
  List<Conversation> conversations = const [];
  List<MessageItem> messages = const [];
  Conversation? selectedConversation;
  String? typingText;
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait(
          [_repository.notifications(), _repository.conversations()]);
      notifications = results[0] as List<NotificationItem>;
      conversations = results[1] as List<Conversation>;
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openConversation(Conversation conversation) async {
    if (selectedConversation?.id != conversation.id &&
        selectedConversation != null) {
      await _realtime.leaveConversation(selectedConversation!.id);
    }
    selectedConversation = conversation;
    await _realtime.joinConversation(conversation.id);
    await _repository.markConversationRead(conversation.id);
    messages = await _repository.messages(conversation.id);
    notifyListeners();
  }

  Future<void> openDirectConversation(String recipientUserId) async {
    final conversation = await _repository.createConversation(recipientUserId);
    conversations = [
      conversation,
      ...conversations.where((item) => item.id != conversation.id)
    ];
    await openConversation(conversation);
  }

  Future<void> sendText(String text) async {
    final conversation = selectedConversation;
    if (conversation == null || text.trim().isEmpty) {
      return;
    }
    final sent = await _repository.sendText(conversation.id, text.trim());
    messages = [...messages, sent];
    notifyListeners();
  }

  Future<void> sendWorkspaceShare(String workspaceId,
      {String role = 'viewer'}) async {
    final conversation = selectedConversation;
    if (conversation == null || workspaceId.trim().isEmpty) {
      return;
    }
    final sent = await _repository.sendWorkspaceShare(
      conversation.id,
      workspaceId: workspaceId,
      role: role,
    );
    messages = [...messages, sent];
    notifyListeners();
  }

  Future<void> acceptWorkspaceShare(MessageItem message) async {
    await _repository.acceptWorkspaceShare(message.id);
  }

  Future<void> markNotificationRead(NotificationItem notification) async {
    await _repository.markNotificationRead(notification.id);
    notifications = notifications
        .map((item) => item.id == notification.id
            ? NotificationItem(
                id: item.id,
                title: item.title,
                message: item.message,
                isRead: true,
                createdDate: item.createdDate)
            : item)
        .toList();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await _repository.markAllNotificationsRead();
    notifications = notifications
        .map((item) => NotificationItem(
            id: item.id,
            title: item.title,
            message: item.message,
            isRead: true,
            createdDate: item.createdDate))
        .toList();
    notifyListeners();
  }

  Future<void> publishTyping(bool isTyping) async {
    final conversation = selectedConversation;
    if (conversation == null) return;
    await _realtime.sendConversationTyping(conversation.id, isTyping);
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in [
      'NotificationCreated',
      'NotificationReadChanged',
      'NotificationUnreadCountChanged'
    ]) {
      _unsubscribe.add(_realtime.on(event, (_) => _debounced(load)));
    }
    for (final event in ['ConversationUpserted', 'ConversationRead']) {
      _unsubscribe.add(_realtime.on(event, (_) => _debounced(load)));
    }
    _unsubscribe.add(_realtime.on('MessageCreated', (payload) async {
      final selected = selectedConversation;
      if (selected != null &&
          (payload.conversationId == null ||
              payload.conversationId == selected.id)) {
        messages = await _repository.messages(selected.id);
        await _repository.markConversationRead(selected.id);
        notifyListeners();
      }
      _debounced(load);
    }));
    _unsubscribe.add(_realtime.on('ConversationTyping', (payload) {
      final selected = selectedConversation;
      if (selected == null || payload.conversationId != selected.id) return;
      typingText = 'Đang nhập...';
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        typingText = null;
        notifyListeners();
      });
    }));
  }

  void _debounced(Future<void> Function() action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => action());
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    if (selectedConversation != null) {
      _realtime.leaveConversation(selectedConversation!.id);
    }
    super.dispose();
  }
}
