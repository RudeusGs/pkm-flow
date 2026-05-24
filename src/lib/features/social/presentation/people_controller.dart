import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';

class PeopleController extends ChangeNotifier {
  PeopleController({required SocialRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final SocialRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  List<FriendItem> friends = const [];
  List<UserSearchResult> results = const [];
  bool isLoading = false;
  String? error;

  Future<void> loadFriends() async {
    isLoading = true;
    notifyListeners();
    try {
      friends = await _repository.friends();
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
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in ['FriendRequestReceived', 'FriendRequestAccepted', 'FriendshipChanged', 'FriendRemoved']) {
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
