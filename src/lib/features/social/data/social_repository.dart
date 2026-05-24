import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/social_models.dart';

class SocialRepository {
  const SocialRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<UserSearchResult>> searchUsers(String keyword) {
    return _apiClient.get<List<UserSearchResult>>(
      'social/users/search',
      query: {'keyword': keyword, 'pageNumber': 1, 'pageSize': 30},
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

  Future<void> sendFriendRequest(String userId) {
    return _apiClient.post<void>('social/friend-requests',
        data: {'addresseeUserId': userId}, parser: (_) {});
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

  Future<void> acceptRequest(String requestId) {
    return _apiClient.post<void>('social/friend-requests/$requestId/accept',
        parser: (_) {});
  }

  Future<void> rejectRequest(String requestId) {
    return _apiClient.post<void>('social/friend-requests/$requestId/reject',
        parser: (_) {});
  }

  Future<void> cancelRequest(String requestId) {
    return _apiClient.post<void>('social/friend-requests/$requestId/cancel',
        parser: (_) {});
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

  Future<void> removeFriend(String friendUserId) {
    return _apiClient.delete<void>('social/friends/$friendUserId',
        parser: (_) {});
  }
}
