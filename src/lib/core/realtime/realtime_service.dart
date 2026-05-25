import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../storage/auth_token_store.dart';
import 'realtime_event.dart';
import 'realtime_events.dart';

typedef RealtimeEventHandler = FutureOr<void> Function(RealtimeEvent event);

class RealtimeService extends ChangeNotifier {
  RealtimeService({required this.tokenStore});

  final AuthTokenStore tokenStore;

  final Map<String, Set<RealtimeEventHandler>> _handlersByEvent = {};
  final Set<String> _registeredConnectionEvents = <String>{};

  /// Desired groups = group user đang muốn nghe.
  /// Active groups = group đã join thành công ở connection hiện tại.
  final Set<String> _joinedWorkspaces = <String>{};
  final Set<String> _joinedPages = <String>{};
  final Set<String> _joinedConversations = <String>{};
  final Set<String> _activeWorkspaces = <String>{};
  final Set<String> _activePages = <String>{};
  final Set<String> _activeConversations = <String>{};

  HubConnection? _connection;
  Future<void>? _startFuture;
  Timer? _retryTimer;

  bool _manualStop = false;
  int _retryAttempt = 0;
  DateTime? _lastStartAttemptAt;

  String status = 'idle';
  String? error;
  DateTime? lastConnectedAt;
  DateTime? lastDisconnectedAt;

  bool get isConnected => status == 'connected';
  bool get isConnecting => status == 'connecting' || status == 'reconnecting';
  bool get hasQueuedGroups =>
      _joinedWorkspaces.isNotEmpty ||
      _joinedPages.isNotEmpty ||
      _joinedConversations.isNotEmpty;

  VoidCallback on(String eventName, RealtimeEventHandler handler) {
    final name = eventName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Realtime eventName không được để trống.');
    }

    final handlers =
        _handlersByEvent.putIfAbsent(name, () => <RealtimeEventHandler>{});
    handlers.add(handler);

    // Register local hub callback nếu connection đã tồn tại. Đây không gọi server.
    final connection = _connection;
    if (connection != null) {
      _registerSingleHubEvent(connection, name);
    }

    return () {
      final current = _handlersByEvent[name];
      current?.remove(handler);
      if (current != null && current.isEmpty) {
        _handlersByEvent.remove(name);
      }
    };
  }

  /// Chỉ start 1 lần tại 1 thời điểm.
  /// Nếu hub lỗi, retry có backoff. Không reconnect kiểu spam nữa.
  Future<void> start({bool userInitiated = false}) {
    if (isConnected) return Future<void>.value();
    if (_startFuture != null) return _startFuture!;

    final now = DateTime.now();
    final lastStart = _lastStartAttemptAt;

    // Chặn những lần start lặp do widget rebuild/join group liên tục.
    if (!userInitiated &&
        lastStart != null &&
        now.difference(lastStart) < const Duration(seconds: 5)) {
      return Future<void>.value();
    }

    _manualStop = false;
    _lastStartAttemptAt = now;
    _startFuture = _startInternal(userInitiated: userInitiated);
    return _startFuture!;
  }

  Future<void> _startInternal({required bool userInitiated}) async {
    final token = await tokenStore.readAccessToken();
    if (token == null || token.trim().isEmpty) {
      error = null;
      _setStatus('idle');
      _startFuture = null;
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;

    _setStatus(status == 'disconnected' || status == 'error'
        ? 'reconnecting'
        : 'connecting');

    try {
      await _disposeConnectionSilently();
      _connection = _buildConnection();

      await _connection!.start()!.timeout(const Duration(seconds: 12));

      _retryAttempt = 0;
      error = null;
      lastConnectedAt = DateTime.now();
      _setStatus('connected');

      await _restoreJoinedGroups();
    } catch (err) {
      await _disposeConnectionSilently();
      _clearActiveGroups();
      error = _errorMessage(err, 'Không kết nối được realtime hub.');
      _setStatus('error');
      _scheduleReconnect();
    } finally {
      _startFuture = null;
    }
  }

  HubConnection _buildConnection() {
    final options = HttpConnectionOptions(
      accessTokenFactory: () async => await tokenStore.readAccessToken() ?? '',
    );

    final connection = HubConnectionBuilder()
        .withUrl(AppConfig.collaborationHubUrl, options: options)
        .build();

    _registerHubEvents(connection);

    connection.onclose(({Exception? error}) {
      if (_manualStop) return;

      _connection = null;
      _clearActiveGroups();
      lastDisconnectedAt = DateTime.now();
      this.error = error == null
          ? 'Realtime đã ngắt kết nối.'
          : _errorMessage(error, 'Realtime đã ngắt kết nối.');
      _setStatus('disconnected');
      _scheduleReconnect();
    });

    return connection;
  }

  void _registerHubEvents(HubConnection connection) {
    _registeredConnectionEvents.clear();
    final eventNames = <String>{
      ...RealtimeEvents.knownBackendEvents,
      ..._handlersByEvent.keys,
    };

    for (final eventName in eventNames) {
      _registerSingleHubEvent(connection, eventName);
    }
  }

  void _registerSingleHubEvent(HubConnection connection, String eventName) {
    final name = eventName.trim();
    if (name.isEmpty || _registeredConnectionEvents.contains(name)) return;
    _registeredConnectionEvents.add(name);
    connection.on(name, (args) => _dispatch(name, args));
  }

  void _dispatch(String eventName, List<Object?>? args) {
    final event = RealtimeEvent.fromSignalR(eventName, args);
    final names = <String>{eventName, event.name};

    for (final name in names) {
      final handlers = List<RealtimeEventHandler>.from(
        _handlersByEvent[name] ?? const <RealtimeEventHandler>{},
      );

      for (final handler in handlers) {
        try {
          final result = handler(event);
          if (result is Future) {
            result.catchError((_) {});
          }
        } catch (_) {
          // Không để 1 handler lỗi kéo sập realtime service.
        }
      }
    }
  }

  void _scheduleReconnect() {
    if (_manualStop) return;
    if (_retryTimer?.isActive == true) return;

    // 5s -> 10s -> 20s -> 40s -> 60s. Không có chuyện bắn request mỗi frame.
    final delaySeconds = switch (_retryAttempt) {
      0 => 5,
      1 => 10,
      2 => 20,
      3 => 40,
      _ => 60,
    };

    _retryAttempt += 1;
    _retryTimer = Timer(Duration(seconds: delaySeconds), () async {
      _retryTimer = null;
      if (_manualStop) return;
      if (!await tokenStore.hasToken()) return;
      await start();
    });
  }

  Future<void> stop() async {
    _manualStop = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _clearDesiredGroups();
    _clearActiveGroups();
    await _disposeConnectionSilently();
    error = null;
    lastDisconnectedAt = DateTime.now();
    _setStatus('disconnected');
  }

  Future<void> joinWorkspace(String workspaceId) async {
    final id = workspaceId.trim();
    if (id.isEmpty) return;

    _joinedWorkspaces.add(id);
    if (!isConnected) {
      // Queue group rồi để start/backoff xử lý. Không invoke liên tục.
      await start();
    }
    if (!isConnected) return;
    if (_activeWorkspaces.contains(id)) return;

    if (await _safeInvoke('JoinWorkspace', <Object>[id])) {
      _activeWorkspaces.add(id);
    }
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    final id = workspaceId.trim();
    if (id.isEmpty) return;

    _joinedWorkspaces.remove(id);
    if (!isConnected || !_activeWorkspaces.remove(id)) return;
    await _safeInvoke('LeaveWorkspace', <Object>[id]);
  }

  Future<void> heartbeatWorkspace(String workspaceId) async {
    final id = workspaceId.trim();
    if (!isConnected || !_activeWorkspaces.contains(id)) return;
    await _safeInvoke('HeartbeatWorkspace', <Object>[id]);
  }

  Future<void> joinPage(String pageId) async {
    final id = pageId.trim();
    if (id.isEmpty) return;

    _joinedPages.add(id);
    if (!isConnected) {
      await start();
    }
    if (!isConnected) return;
    if (_activePages.contains(id)) return;

    if (await _safeInvoke('JoinPage', <Object>[id])) {
      _activePages.add(id);
    }
  }

  Future<void> leavePage(String pageId) async {
    final id = pageId.trim();
    if (id.isEmpty) return;

    _joinedPages.remove(id);
    if (!isConnected || !_activePages.remove(id)) return;
    await _safeInvoke('LeavePage', <Object>[id]);
  }

  Future<void> heartbeatPage(String pageId) async {
    final id = pageId.trim();
    if (!isConnected || !_activePages.contains(id)) return;
    await _safeInvoke('HeartbeatPage', <Object>[id]);
  }

  Future<void> joinConversation(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    _joinedConversations.add(id);
    if (!isConnected) {
      start();
      return;
    }
    if (_activeConversations.contains(id)) return;

    if (await _safeInvoke('JoinConversation', <Object>[id])) {
      _activeConversations.add(id);
    }
  }

  Future<void> leaveConversation(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    _joinedConversations.remove(id);
    if (!isConnected || !_activeConversations.remove(id)) return;
    await _safeInvoke('LeaveConversation', <Object>[id]);
  }

  Future<void> sendConversationTyping(
    String conversationId,
    bool isTyping,
  ) async {
    final id = conversationId.trim();
    if (!isConnected || !_activeConversations.contains(id)) return;
    await _safeInvoke('SendConversationTyping', <Object>[
      {'conversationId': id, 'isTyping': isTyping}
    ]);
  }

  Future<void> sendBlockDraft({
    required String pageId,
    required String blockId,
    required String editorSessionId,
    required int baseRevision,
    required int clientSequence,
    String? type,
    String? textContent,
    String? propsJson,
  }) async {
    // Draft là event tần suất cao. Nếu realtime chưa sẵn sàng thì bỏ qua,
    // tuyệt đối không start lại mỗi lần gõ phím.
    if (!isConnected || !_activePages.contains(pageId)) return;

    await _safeInvoke('SendBlockDraft', <Object>[
      {
        'pageId': pageId,
        'blockId': blockId,
        'editorSessionId': editorSessionId,
        'baseRevision': baseRevision,
        'clientSequence': clientSequence,
        'type': type,
        'textContent': textContent,
        'propsJson': propsJson,
      }
    ]);
  }

  Future<void> sendBlockEditingState({
    required String pageId,
    required String blockId,
    required String editorSessionId,
    required bool isEditing,
  }) async {
    if (!isConnected || !_activePages.contains(pageId)) return;

    await _safeInvoke('SendBlockEditingState', <Object>[
      {
        'pageId': pageId,
        'blockId': blockId,
        'editorSessionId': editorSessionId,
        'isEditing': isEditing,
      }
    ]);
  }

  Future<void> _restoreJoinedGroups() async {
    if (!isConnected) return;

    _clearActiveGroups();

    for (final workspaceId in List<String>.from(_joinedWorkspaces)) {
      if (await _safeInvoke('JoinWorkspace', <Object>[workspaceId])) {
        _activeWorkspaces.add(workspaceId);
      }
    }

    for (final pageId in List<String>.from(_joinedPages)) {
      if (await _safeInvoke('JoinPage', <Object>[pageId])) {
        _activePages.add(pageId);
      }
    }

    for (final conversationId in List<String>.from(_joinedConversations)) {
      if (await _safeInvoke('JoinConversation', <Object>[conversationId])) {
        _activeConversations.add(conversationId);
      }
    }
  }

  Future<bool> _safeInvoke(String methodName, List<Object> args) async {
    final connection = _connection;
    if (connection == null || !isConnected) return false;

    try {
      await connection.invoke(methodName, args: args);
      return true;
    } catch (err) {
      error = _errorMessage(err, 'Realtime request thất bại.');
      notifyListeners();
      return false;
    }
  }

  Future<void> _disposeConnectionSilently() async {
    final connection = _connection;
    _connection = null;
    _registeredConnectionEvents.clear();
    if (connection == null) return;

    try {
      await connection.stop();
    } catch (_) {
      // ignore
    }
  }

  void _clearDesiredGroups() {
    _joinedWorkspaces.clear();
    _joinedPages.clear();
    _joinedConversations.clear();
  }

  void _clearActiveGroups() {
    _activeWorkspaces.clear();
    _activePages.clear();
    _activeConversations.clear();
  }

  void _setStatus(String value) {
    if (status == value) return;
    status = value;
    notifyListeners();
  }

  String _errorMessage(Object error, String fallback) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  void dispose() {
    _manualStop = true;
    _retryTimer?.cancel();
    _clearDesiredGroups();
    _clearActiveGroups();
    _connection?.stop();
    _connection = null;
    super.dispose();
  }
}
