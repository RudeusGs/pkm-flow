import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';

class PeopleController extends ChangeNotifier {
  PeopleController({
    required SocialRepository repository,
    required RealtimeService realtime,
  })  : _repository = repository,
        _realtime = realtime;

  final SocialRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  List<FriendItem> friends = const [];
  List<FriendRequestItem> incomingRequests = const [];
  List<FriendRequestItem> outgoingRequests = const [];
  List<UserSearchResult> results = const [];

  bool isLoading = false;
  bool isSearching = false;
  bool isBusy = false;
  String? error;
  String activeKeyword = '';
  String? searchHint;

  bool get hasSearchQuery => activeKeyword.trim().isNotEmpty;
  bool get canSearch => activeKeyword.trim().length >= 2;

  bool isFriendUser(String userId) {
    final id = userId.trim().toLowerCase();
    if (id.isEmpty) return false;
    return friends.any((friend) => friend.userId.trim().toLowerCase() == id);
  }

  String effectiveStatus(UserSearchResult user) {
    if (user.isSelf) return 'self';
    if (user.isFriend || isFriendUser(user.id)) return 'friends';
    return user.friendshipStatus;
  }

  Future<void> loadFriends({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      notifyListeners();
    }

    try {
      await _reloadSocialData();
      _syncSearchResultsWithFriends();
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      if (!silent) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  void clearSearch() {
    activeKeyword = '';
    searchHint = null;
    results = const [];
    error = null;
    isSearching = false;
    notifyListeners();
  }

  Future<void> search(String keyword) async {
    final text = keyword.trim();
    activeKeyword = text;

    if (text.isEmpty) {
      clearSearch();
      return;
    }

    if (text.length < 2) {
      results = const [];
      searchHint = 'Nhập ít nhất 2 ký tự để tìm người dùng.';
      error = null;
      isSearching = false;
      notifyListeners();
      return;
    }

    isSearching = true;
    searchHint = null;
    error = null;
    notifyListeners();

    try {
      final found = await _repository.searchUsers(text);
      if (activeKeyword != text) return;

      results = found
          .map(
            (user) => isFriendUser(user.id)
                ? user.copyWith(friendshipStatus: 'friends')
                : user,
          )
          .toList();
      searchHint = results.isEmpty
          ? 'Không tìm thấy ai khớp "$text". Thử username hoặc tên đầy đủ nha.'
          : null;
    } catch (err) {
      if (activeKeyword != text) return;
      results = const [];
      error = err.toString();
    } finally {
      if (activeKeyword == text) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendRequest(UserSearchResult user) async {
    if (isBusy || effectiveStatus(user) != 'none') return;

    await _run(() async {
      await _repository.sendFriendRequest(user.id);
      await _reloadSocialData();
      await search(activeKeyword.isNotEmpty ? activeKeyword : user.userName);
    });
  }

  Future<void> acceptRequest(FriendRequestItem request) async {
    if (isBusy) return;

    await _run(() async {
      await _repository.acceptRequest(request.id);
      await _reloadSocialData();
      _syncSearchResultsWithFriends();
    });
  }

  Future<void> rejectRequest(FriendRequestItem request) async {
    if (isBusy) return;

    await _run(() async {
      await _repository.rejectRequest(request.id);
      await _reloadSocialData();
      _syncSearchResultsWithFriends();
    });
  }

  Future<void> cancelRequest(FriendRequestItem request) async {
    if (isBusy) return;

    await _run(() async {
      await _repository.cancelRequest(request.id);
      await _reloadSocialData();
      _syncSearchResultsWithFriends();
    });
  }

  Future<void> removeFriend(FriendItem friend) async {
    if (isBusy) return;

    await _run(() async {
      await _repository.removeFriend(friend.userId);
      await _reloadSocialData();
      _syncSearchResultsWithFriends();
    });
  }

  Future<void> _reloadSocialData() async {
    final loadedFriends = await _repository.friends();
    final incoming = await _repository.incomingRequests();
    final outgoing = await _repository.outgoingRequests();

    friends = loadedFriends;
    incomingRequests = incoming;
    outgoingRequests = outgoing;
  }

  void _syncSearchResultsWithFriends() {
    if (results.isEmpty) return;
    results = results
        .map(
          (user) => isFriendUser(user.id)
              ? user.copyWith(friendshipStatus: 'friends')
              : user,
        )
        .toList();
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    error = null;
    notifyListeners();

    try {
      await action();
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;

    for (final event in const [
      'FriendRequestReceived',
      'FriendRequestSent',
      'FriendRequestAccepted',
      'FriendRequestRejected',
      'FriendRequestCancelled',
      'FriendshipChanged',
      'FriendRemoved',
    ]) {
      _unsubscribe.add(
        _realtime.on(event, (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 450), () {
            loadFriends(silent: true);
          });
        }),
      );
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
