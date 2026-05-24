import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/social_models.dart';

class SocialRepository {
  const SocialRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<UserSearchResult>> searchUsers(String keyword) {
    return _apiClient.get<List<UserSearchResult>>(
      'social/users/search',
      query: {'keyword': keyword, 'pageNumber': 1, 'pageSize': 30},
      parser: (json) {
        if (json is List) return json.map((item) => UserSearchResult.fromJson(asMap(item))).toList();
        return parsePagedItems(json, UserSearchResult.fromJson);
      },
    );
  }

  Future<void> sendFriendRequest(String userId) {
    return _apiClient.post<void>('social/friend-requests', data: {'addresseeUserId': userId}, parser: (_) {});
  }

  Future<List<FriendItem>> friends() {
    return _apiClient.get<List<FriendItem>>(
      'social/friends',
      query: const {'pageNumber': 1, 'pageSize': 100},
      parser: (json) {
        if (json is List) return json.map((item) => FriendItem.fromJson(asMap(item))).toList();
        return parsePagedItems(json, FriendItem.fromJson);
      },
    );
  }
}
