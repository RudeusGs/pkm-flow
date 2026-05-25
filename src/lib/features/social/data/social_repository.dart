import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/social_models.dart';

class SocialRepository {
  const SocialRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<UserSearchResult>> searchUsers(String keyword) {
    final text = keyword.trim();
    if (text.length < 2) return Future.value(const <UserSearchResult>[]);

    return _apiClient.get<List<UserSearchResult>>(
      'social/users/search',
      query: {'keyword': text, 'pageNumber': 1, 'pageSize': 30},
      parser: (json) {
        if (json is List) {
          return json
              .map((item) => UserSearchResult.fromJson(asMap(item)))
              .toList();
        }
        return parsePagedItems(json, UserSearchResult.fromJson);
      },
    );
  }

  Future<FriendRequestItem> sendFriendRequest(String userId) {
    return _apiClient.post<FriendRequestItem>(
      'social/friend-requests',
      data: {'addresseeUserId': userId},
      parser: (json) => FriendRequestItem.fromJson(asMap(json)),
    );
  }

  Future<List<FriendRequestItem>> incomingRequests() {
    return _apiClient.get<List<FriendRequestItem>>(
      'social/friend-requests/incoming',
      query: const {'pageNumber': 1, 'pageSize': 50},
      parser: (json) {
        if (json is List) {
          return json
              .map((item) => FriendRequestItem.fromJson(asMap(item)))
              .toList();
        }
        return parsePagedItems(json, FriendRequestItem.fromJson);
      },
    );
  }

  Future<List<FriendRequestItem>> outgoingRequests() {
    return _apiClient.get<List<FriendRequestItem>>(
      'social/friend-requests/outgoing',
      query: const {'pageNumber': 1, 'pageSize': 50},
      parser: (json) {
        if (json is List) {
          return json
              .map((item) => FriendRequestItem.fromJson(asMap(item)))
              .toList();
        }
        return parsePagedItems(json, FriendRequestItem.fromJson);
      },
    );
  }

  Future<FriendRequestItem> acceptRequest(String requestId) {
    return _apiClient.post<FriendRequestItem>(
      'social/friend-requests/$requestId/accept',
      parser: (json) => FriendRequestItem.fromJson(asMap(json)),
    );
  }

  Future<FriendRequestItem> rejectRequest(String requestId) {
    return _apiClient.post<FriendRequestItem>(
      'social/friend-requests/$requestId/reject',
      parser: (json) => FriendRequestItem.fromJson(asMap(json)),
    );
  }

  Future<FriendRequestItem> cancelRequest(String requestId) {
    return _apiClient.post<FriendRequestItem>(
      'social/friend-requests/$requestId/cancel',
      parser: (json) => FriendRequestItem.fromJson(asMap(json)),
    );
  }

  Future<List<FriendItem>> friends() {
    return _apiClient.get<List<FriendItem>>(
      'social/friends',
      query: const {'pageNumber': 1, 'pageSize': 100},
      parser: (json) {
        if (json is List) {
          return json.map((item) => FriendItem.fromJson(asMap(item))).toList();
        }
        return parsePagedItems(json, FriendItem.fromJson);
      },
    );
  }

  Future<void> removeFriend(String userId) {
    return _apiClient.delete<void>(
      'social/friends/$userId',
      parser: (_) {},
    );
  }
}


