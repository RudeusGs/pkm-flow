import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/utils/json_utils.dart';
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
  final Set<String> _conversationSubscriptions = <String>{};
  Timer? _debounce;
  Timer? _conversationListSync;
  bool _isLoadingConversations = false;

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
      unawaited(_ensureRealtime());
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
      unawaited(_ensureRealtime());
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
    if (_isLoadingConversations) return;

    _isLoadingConversations = true;
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      conversations = await _repository.conversations();
      _bindRealtime();
      await _syncConversationSubscriptions();
      _startConversationListAutoSync();
      unawaited(_ensureRealtime());
    } catch (err) {
      error = err.toString();
    } finally {
      _isLoadingConversations = false;
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
    _markConversationReadLocally(conversation.id);
    notifyListeners();
  }

  Future<void> closeConversation() async {
    final conversation = selectedConversation;
    if (conversation == null) return;

    selectedConversation = null;
    typingText = null;
    messages = const [];
    // Vẫn giữ subscription conversation ở màn list để preview tin nhắn mới
    // cập nhật ngay, không cần mở chat mới thấy.
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
      _upsertConversationPreview(sent, forceRead: true);
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
      _upsertConversationPreview(sent, forceRead: true);
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
    _upsertConversationPreview(message, forceRead: true);
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

  Future<void> _syncConversationSubscriptions() async {
    final nextIds = conversations
        .map((conversation) => conversation.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final removed in _conversationSubscriptions.difference(nextIds)) {
      await _realtime.leaveConversation(removed);
    }

    for (final added in nextIds.difference(_conversationSubscriptions)) {
      await _realtime.joinConversation(added);
    }

    _conversationSubscriptions
      ..clear()
      ..addAll(nextIds);
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;

    for (final event in [
      'NotificationCreated',
      'NotificationReadChanged',
      'NotificationUnreadCountChanged'
    ]) {
      _unsubscribe.add(_realtime.on(event, (_) {
        _debounced(() async {
          await loadNotifications(silent: true);
          await loadConversations(silent: true);
        });
      }));
    }

    for (final event in ['ConversationUpserted', 'ConversationRead']) {
      _unsubscribe.add(_realtime.on(
        event,
        (_) => _debounced(() => loadConversations(silent: true)),
      ));
    }

    _unsubscribe.add(_realtime.on('MessageCreated', (payload) async {
      final message = _messageFromRealtime(payload);
      final conversationId = payload.conversationId ?? message?.conversationId;
      final selected = selectedConversation;
      final isSelected = selected != null &&
          (conversationId == null || conversationId == selected.id);

      if (message != null) {
        _upsertConversationPreview(message, forceRead: isSelected);
      }

      if (selected != null && isSelected) {
        if (message != null) {
          _upsertMessage(message);
        } else {
          messages = await _repository.messages(selected.id);
          notifyListeners();
        }
        await _repository.markConversationRead(selected.id);
        _markConversationReadLocally(selected.id);
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

  MessageItem? _messageFromRealtime(RealtimeEvent event) {
    final payload = event.payloadMap;
    if (payload.isEmpty) return null;

    final conversationId = asString(
      payload['conversationId'],
      event.conversationId ?? '',
    );
    final id = asString(payload['id']);
    if (id.isEmpty || conversationId.isEmpty) return null;

    try {
      return MessageItem.fromJson({...payload, 'conversationId': conversationId});
    } catch (_) {
      return null;
    }
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

  void _upsertConversationPreview(
    MessageItem message, {
    bool forceRead = false,
  }) {
    final index = conversations.indexWhere(
      (item) => item.id == message.conversationId,
    );
    if (index < 0) return;

    final current = conversations[index];
    final shouldCountUnread = !forceRead &&
        !message.isMine &&
        selectedConversation?.id != message.conversationId;

    final updated = current.copyWith(
      lastMessagePreview: _previewForMessage(message),
      lastMessageAtUtc:
          message.createdDate ?? DateTime.now().toUtc().toIso8601String(),
      unreadCount: shouldCountUnread
          ? current.unreadCount + 1
          : (forceRead ? 0 : current.unreadCount),
    );

    final next = [
      updated,
      ...conversations.where((item) => item.id != updated.id),
    ];
    conversations = next;
    notifyListeners();
  }

  void _markConversationReadLocally(String conversationId) {
    conversations = conversations
        .map((item) => item.id == conversationId
            ? item.copyWith(unreadCount: 0)
            : item)
        .toList();
    notifyListeners();
  }

  String _previewForMessage(MessageItem message) {
    final type = message.type.toLowerCase();
    final body = message.body.trim();

    if (type == 'workspaceshare') return 'Đã chia sẻ một workspace';
    if (type == 'image') return body.isEmpty ? 'Đã gửi một ảnh' : body;
    return body.isEmpty ? 'Tin nhắn mới' : body;
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
    _debounce = Timer(const Duration(milliseconds: 250), () => action());
  }

  void _startConversationListAutoSync() {
    if (_conversationListSync?.isActive == true) return;

    _conversationListSync = Timer.periodic(const Duration(seconds: 4), (_) {
      if (selectedConversation != null || _isLoadingConversations) return;
      unawaited(loadConversations(silent: true));
    });
  }

  Future<void> _ensureRealtime() async {
    try {
      await _realtime.start(userInitiated: true);
    } catch (_) {
      // RealtimeService đã giữ trạng thái lỗi và tự retry. UI list vẫn dùng API fallback.
    }
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    _conversationListSync?.cancel();
    for (final id in _conversationSubscriptions) {
      _realtime.leaveConversation(id);
    }
    if (selectedConversation != null &&
        !_conversationSubscriptions.contains(selectedConversation!.id)) {
      _realtime.leaveConversation(selectedConversation!.id);
    }
    super.dispose();
  }
}