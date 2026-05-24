import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';

class PeopleController extends ChangeNotifier {
  PeopleController(
      {required SocialRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final SocialRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  List<FriendItem> friends = const [];
  List<FriendRequestItem> incoming = const [];
  List<FriendRequestItem> outgoing = const [];
  List<UserSearchResult> results = const [];
  bool isLoading = false;
  String? error;

  Future<void> loadFriends() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.friends(),
        _repository.incomingRequests(),
        _repository.outgoingRequests(),
      ]);
      friends = results[0] as List<FriendItem>;
      incoming = results[1] as List<FriendRequestItem>;
      outgoing = results[2] as List<FriendRequestItem>;
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      results = const [];
      notifyListeners();
      return;
    }
    results = await _repository.searchUsers(keyword.trim());
    notifyListeners();
  }

  Future<void> sendRequest(UserSearchResult user) async {
    await _repository.sendFriendRequest(user.id);
    await search(user.userName);
    outgoing = await _repository.outgoingRequests();
    notifyListeners();
  }

  Future<void> accept(FriendRequestItem request) async {
    await _repository.acceptRequest(request.id);
    await loadFriends();
  }

  Future<void> reject(FriendRequestItem request) async {
    await _repository.rejectRequest(request.id);
    await loadFriends();
  }

  Future<void> cancel(FriendRequestItem request) async {
    await _repository.cancelRequest(request.id);
    await loadFriends();
  }

  Future<void> removeFriend(FriendItem friend) async {
    await _repository.removeFriend(friend.userId);
    await loadFriends();
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in [
      'FriendRequestReceived',
      'FriendRequestSent',
      'FriendRequestAccepted',
      'FriendRequestRejected',
      'FriendRequestCancelled',
      'FriendshipChanged',
      'FriendRemoved'
    ]) {
      _unsubscribe.add(_realtime.on(event, (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), loadFriends);
      }));
    }
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    super.dispose();
  }
}
