import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../../workspaces/domain/workspace.dart';
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
  int unreadNotifications = 0;
  List<Conversation> conversations = const [];
  List<MessageItem> messages = const [];
  Conversation? selectedConversation;
  String? typingText;
  bool isLoading = false;
  bool isSendingMessage = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait(
          [loadNotifications(silent: true), loadConversations(silent: true)]);
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications(
      {bool silent = false, String? workspaceId}) async {
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _repository.notifications(workspaceId: workspaceId),
        _repository.unreadNotificationCount(workspaceId: workspaceId),
      ]);
      notifications = results[0] as List<NotificationItem>;
      unreadNotifications = results[1] as int;
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      if (!silent) isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markNotificationRead(NotificationItem item) async {
    try {
      if (!item.isRead) {
        await _repository.markNotificationRead(item.id);
      }
      await loadNotifications(silent: true);
      return true;
    } catch (err) {
      error = err.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markNotificationUnread(NotificationItem item) async {
    try {
      if (item.isRead) {
        await _repository.markNotificationUnread(item.id);
      }
      await loadNotifications(silent: true);
      return true;
    } catch (err) {
      error = err.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> markAllNotificationsRead({String? workspaceId}) async {
    await _repository.markAllNotificationsRead(workspaceId: workspaceId);
    await loadNotifications(silent: true, workspaceId: workspaceId);
  }

  Future<bool> deleteNotification(NotificationItem item) async {
    try {
      await _repository.deleteNotification(item.id);
      notifications =
          notifications.where((entry) => entry.id != item.id).toList();
      if (!item.isRead) {
        final nextUnread = unreadNotifications - 1;
        unreadNotifications = nextUnread < 0 ? 0 : nextUnread;
      }
      notifyListeners();
      return true;
    } catch (err) {
      error = err.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      conversations = await _repository.conversations();
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      if (!silent) isLoading = false;
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

  Future<void> sendText(String text) async {
    final conversation = selectedConversation;
    if (conversation == null || text.trim().isEmpty || isSendingMessage) return;

    isSendingMessage = true;
    error = null;
    notifyListeners();
    try {
      final sent = await _repository.sendText(conversation.id, text.trim());
      _upsertMessage(sent);
      await loadConversations(silent: true);
    } finally {
      isSendingMessage = false;
      notifyListeners();
    }
  }

  Future<void> sendImage({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    String? caption,
  }) async {
    final conversation = selectedConversation;
    if (conversation == null || bytes.isEmpty || isSendingMessage) return;

    isSendingMessage = true;
    error = null;
    notifyListeners();
    try {
      final sent = await _repository.sendImage(
        conversation.id,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        caption: caption,
      );
      _upsertMessage(sent);
      await loadConversations(silent: true);
    } finally {
      isSendingMessage = false;
      notifyListeners();
    }
  }

  Future<void> sendWorkspaceShare(
      {required Conversation conversation,
      required Workspace workspace,
      required String role}) async {
    final message = await _repository.sendWorkspaceShare(conversation.id,
        workspaceId: workspace.id, role: role);
    if (selectedConversation?.id == conversation.id) {
      _upsertMessage(message);
    }
    await loadConversations(silent: true);
  }

  Future<Workspace> acceptWorkspaceShare(MessageItem message) async {
    final workspace = await _repository.acceptWorkspaceShare(message.id);
    await loadConversations(silent: true);
    notifyListeners();
    return workspace;
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
      _unsubscribe.add(_realtime.on(
          event, (_) => _debounced(() => loadNotifications(silent: true))));
    }
    for (final event in ['ConversationUpserted', 'ConversationRead']) {
      _unsubscribe.add(_realtime.on(
          event, (_) => _debounced(() => loadConversations(silent: true))));
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
      _debounced(() => loadConversations(silent: true));
    }));
    _unsubscribe.add(_realtime.on('ConversationTyping', (payload) {
      final selected = selectedConversation;
      if (selected == null || payload.conversationId != selected.id) return;
      typingText = 'Typing...';
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        typingText = null;
        notifyListeners();
      });
    }));
  }

  void _upsertMessage(MessageItem message) {
    final next = [...messages];
    final index = next.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      next[index] = message;
    } else {
      next.add(message);
    }
    next.sort(_compareMessagesOldestFirst);
    messages = next;
    notifyListeners();
  }

  static int _compareMessagesOldestFirst(MessageItem a, MessageItem b) {
    final left = DateTime.tryParse(a.createdDate ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final right = DateTime.tryParse(b.createdDate ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final result = left.compareTo(right);
    return result == 0 ? a.id.compareTo(b.id) : result;
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
