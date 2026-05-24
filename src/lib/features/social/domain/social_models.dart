import '../../../core/utils/json_utils.dart';

class UserSearchResult {
  const UserSearchResult(
      {required this.id,
      required this.userName,
      required this.fullName,
      this.avatarUrl,
      this.friendshipStatus = 'none'});

  final String id;
  final String userName;
  final String fullName;
  final String? avatarUrl;
  final String friendshipStatus;

  factory UserSearchResult.fromJson(JsonMap json) => UserSearchResult(
        id: asString(json['id']),
        userName: asString(json['userName']),
        fullName:
            asString(json['fullName'], asString(json['userName'], 'User')),
        avatarUrl: json['avatarUrl']?.toString(),
        friendshipStatus: asString(json['friendshipStatus'], 'none'),
      );
}

class FriendItem {
  const FriendItem(
      {required this.userId,
      required this.userName,
      required this.fullName,
      this.avatarUrl});

  final String userId;
  final String userName;
  final String fullName;
  final String? avatarUrl;

  factory FriendItem.fromJson(JsonMap json) => FriendItem(
        userId: asString(json['userId']),
        userName: asString(json['userName']),
        fullName:
            asString(json['fullName'], asString(json['userName'], 'Friend')),
        avatarUrl: json['avatarUrl']?.toString(),
      );
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.status,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherFullName,
    this.otherAvatarUrl,
    this.createdDate,
  });

  final String id;
  final String status;
  final String otherUserId;
  final String otherUserName;
  final String otherFullName;
  final String? otherAvatarUrl;
  final String? createdDate;

  factory FriendRequestItem.fromJson(JsonMap json) {
    final other = asMap(json['otherUser']);
    return FriendRequestItem(
      id: asString(json['id']),
      status: asString(json['status']),
      otherUserId: asString(other['id']),
      otherUserName: asString(other['userName']),
      otherFullName:
          asString(other['fullName'], asString(other['userName'], 'User')),
      otherAvatarUrl: other['avatarUrl']?.toString(),
      createdDate: json['createdDate']?.toString(),
    );
  }
}
