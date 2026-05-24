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

  String status = 'idle';
  String? error;
  DateTime? lastConnectedAt;
  DateTime? lastDisconnectedAt;

  bool get isConnected => status == 'connected';
  bool get isConnecting => status == 'connecting' || status == 'reconnecting';

  VoidCallback on(String eventName, RealtimeEventHandler handler) {
    final handlers =
        _handlersByEvent.putIfAbsent(eventName, () => <RealtimeEventHandler>{});
    handlers.add(handler);
    return () => handlers.remove(handler);
  }

  Future<void> start() {
    if (isConnected) return Future<void>.value();
    if (_startFuture != null) return _startFuture!;

    _manualStop = false;
    _startFuture = _startInternal();
    return _startFuture!;
  }

  Future<void> _startInternal() async {
    _setStatus(status == 'disconnected' ? 'reconnecting' : 'connecting');
    try {
      _connection ??= _buildConnection();
      await _connection!.start();
      error = null;
      lastConnectedAt = DateTime.now();
      _retryTimer?.cancel();
      _setStatus('connected');
      await _restoreJoinedGroups();
    } catch (err) {
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

    for (final eventName in RealtimeEvents.knownBackendEvents) {
      connection.on(eventName, (arguments) => _dispatch(eventName, arguments));
      final lowerEventName = eventName.toLowerCase();
      if (lowerEventName != eventName) {
        connection.on(
            lowerEventName, (arguments) => _dispatch(eventName, arguments));
      }
    }
    connection.onclose(({Exception? error}) {
      if (_manualStop) return;
      this.error = error == null
          ? null
          : _errorMessage(error, 'Realtime đã ngắt kết nối.');
      lastDisconnectedAt = DateTime.now();
      _connection = null;
      _clearActiveGroups();
      _setStatus('disconnected');
      _scheduleReconnect();
    });
    return connection;
  }

  void _dispatch(String eventName, List<Object?>? arguments) {
    final event = RealtimeEvent.fromSignalR(eventName, arguments);
    final handlers = List<RealtimeEventHandler>.from(
        _handlersByEvent[eventName] ?? const <RealtimeEventHandler>{});
    for (final handler in handlers) {
      Future.sync(() => handler(event)).catchError((_) {});
    }
  }

  Future<T?> invoke<T>(String methodName, [List<Object>? args]) async {
    await start();
    if (!isConnected || _connection == null) return null;
    try {
      return await _connection!.invoke(methodName, args: args) as T?;
    } catch (err) {
      error = _errorMessage(err, 'Gọi realtime hub thất bại.');
      notifyListeners();
      return null;
    }
  }

  Future<void> stop() async {
    _manualStop = true;
    _clearDesiredGroups();
    _clearActiveGroups();
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    lastDisconnectedAt = DateTime.now();
    _setStatus('disconnected');
  }

  Future<void> joinWorkspace(String workspaceId) async {
    _joinedWorkspaces.add(workspaceId);
    if (_activeWorkspaces.contains(workspaceId) && isConnected) {
      return;
    }
    await start();
    final connection = _connection;
    if (connection == null ||
        !isConnected ||
        _activeWorkspaces.contains(workspaceId)) {
      return;
    }
    if (await _safeInvokeConnected(
        connection, 'JoinWorkspace', <Object>[workspaceId])) {
      _activeWorkspaces.add(workspaceId);
    }
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    _joinedWorkspaces.remove(workspaceId);
    _activeWorkspaces.remove(workspaceId);
    final connection = _connection;
    if (connection == null || !isConnected) {
      return;
    }
    await _safeInvokeConnected(
        connection, 'LeaveWorkspace', <Object>[workspaceId]);
  }

  Future<void> heartbeatWorkspace(String workspaceId) =>
      invoke<void>('HeartbeatWorkspace', <Object>[workspaceId]);

  Future<void> joinPage(String pageId) async {
    _joinedPages.add(pageId);
    if (_activePages.contains(pageId) && isConnected) {
      return;
    }
    await start();
    final connection = _connection;
    if (connection == null || !isConnected || _activePages.contains(pageId)) {
      return;
    }
    if (await _safeInvokeConnected(connection, 'JoinPage', <Object>[pageId])) {
      _activePages.add(pageId);
    }
  }

  Future<void> leavePage(String pageId) async {
    _joinedPages.remove(pageId);
    _activePages.remove(pageId);
    final connection = _connection;
    if (connection == null || !isConnected) {
      return;
    }
    await _safeInvokeConnected(connection, 'LeavePage', <Object>[pageId]);
  }

  Future<void> heartbeatPage(String pageId) =>
      invoke<void>('HeartbeatPage', <Object>[pageId]);

  Future<void> joinConversation(String conversationId) async {
    _joinedConversations.add(conversationId);
    if (_activeConversations.contains(conversationId) && isConnected) {
      return;
    }
    await start();
    final connection = _connection;
    if (connection == null ||
        !isConnected ||
        _activeConversations.contains(conversationId)) {
      return;
    }
    if (await _safeInvokeConnected(
        connection, 'JoinConversation', <Object>[conversationId])) {
      _activeConversations.add(conversationId);
    }
  }

  Future<void> leaveConversation(String conversationId) async {
    _joinedConversations.remove(conversationId);
    _activeConversations.remove(conversationId);
    final connection = _connection;
    if (connection == null || !isConnected) {
      return;
    }
    await _safeInvokeConnected(
        connection, 'LeaveConversation', <Object>[conversationId]);
  }

  Future<void> sendConversationTyping(String conversationId, bool isTyping) {
    return invoke<void>('SendConversationTyping', <Object>[
      <String, Object?>{'conversationId': conversationId, 'isTyping': isTyping}
    ]);
  }

  Future<void> sendBlockDraft({
    required String pageId,
    required String blockId,
    required String editorSessionId,
    required int baseRevision,
    required int clientSequence,
    required String textContent,
    String? type,
    String? propsJson,
  }) {
    return invoke<void>('SendBlockDraft', <Object>[
      <String, Object?>{
        'pageId': pageId,
        'blockId': blockId,
        'editorSessionId': editorSessionId,
        'baseRevision': baseRevision,
        'clientSequence': clientSequence,
        'textContent': textContent,
        'type': type,
        'propsJson': propsJson,
      },
    ]);
  }

  Future<void> sendBlockEditingState({
    required String pageId,
    required String blockId,
    required String editorSessionId,
    required bool isEditing,
  }) {
    return invoke<void>('SendBlockEditingState', <Object>[
      <String, Object?>{
        'pageId': pageId,
        'blockId': blockId,
        'editorSessionId': editorSessionId,
        'isEditing': isEditing,
      },
    ]);
  }

  void _scheduleReconnect() {
    if (_manualStop) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (!_manualStop && !isConnected) start();
    });
  }

  Future<void> _restoreJoinedGroups() async {
    final connection = _connection;
    if (connection == null || !isConnected) return;

    for (final workspaceId in List<String>.from(_joinedWorkspaces)) {
      if (await _safeInvokeConnected(
          connection, 'JoinWorkspace', <Object>[workspaceId])) {
        _activeWorkspaces.add(workspaceId);
      }
    }
    for (final pageId in List<String>.from(_joinedPages)) {
      if (await _safeInvokeConnected(
          connection, 'JoinPage', <Object>[pageId])) {
        _activePages.add(pageId);
      }
    }
    for (final conversationId in List<String>.from(_joinedConversations)) {
      if (await _safeInvokeConnected(
          connection, 'JoinConversation', <Object>[conversationId])) {
        _activeConversations.add(conversationId);
      }
    }
  }

  Future<bool> _safeInvokeConnected(
      HubConnection connection, String methodName, List<Object> args) async {
    try {
      await connection.invoke(methodName, args: args);
      return true;
    } catch (err) {
      error = _errorMessage(err, 'Không khôi phục được realtime group.');
      notifyListeners();
      return false;
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
    _clearDesiredGroups();
    _clearActiveGroups();
    _retryTimer?.cancel();
    _connection?.stop();
    super.dispose();
  }
}
