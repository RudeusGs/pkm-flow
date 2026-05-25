import '../../../core/utils/json_utils.dart';

String normalizeFriendshipStatus(Object? value, {bool isCurrentUser = false}) {
  if (isCurrentUser) return 'self';

  final raw = asString(value).trim().toLowerCase();
  final compact = raw
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .replaceAll('__', '_');

  switch (compact) {
    case '':
    case 'none':
    case 'not_friend':
    case 'not_friends':
    case 'stranger':
      return 'none';
    case 'self':
    case 'me':
    case 'current_user':
      return 'self';
    case 'friend':
    case 'friends':
    case 'accepted':
      return 'friends';
    case 'request_sent':
    case 'sent':
    case 'outgoing':
    case 'pending_sent':
    case 'pending_outgoing':
      return 'request_sent';
    case 'request_received':
    case 'received':
    case 'incoming':
    case 'pending_received':
    case 'pending_incoming':
      return 'request_received';
    default:
      if (compact.contains('friend') && !compact.contains('not')) {
        return 'friends';
      }
      if (compact.contains('sent') || compact.contains('outgoing')) {
        return 'request_sent';
      }
      if (compact.contains('received') || compact.contains('incoming')) {
        return 'request_received';
      }
      return 'none';
  }
}

class UserSearchResult {
  const UserSearchResult({
    required this.id,
    required this.userName,
    required this.fullName,
    this.avatarUrl,
    this.friendshipStatus = 'none',
    this.isCurrentUser = false,
  });

  final String id;
  final String userName;
  final String fullName;
  final String? avatarUrl;
  final String friendshipStatus;
  final bool isCurrentUser;

  bool get isSelf => friendshipStatus == 'self' || isCurrentUser;
  bool get isFriend => friendshipStatus == 'friends';
  bool get canSendRequest => friendshipStatus == 'none';

  UserSearchResult copyWith({
    String? friendshipStatus,
  }) {
    return UserSearchResult(
      id: id,
      userName: userName,
      fullName: fullName,
      avatarUrl: avatarUrl,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      isCurrentUser: isCurrentUser,
    );
  }

  factory UserSearchResult.fromJson(JsonMap json) {
    final isCurrentUser = asBool(json['isCurrentUser']);
    return UserSearchResult(
      id: asString(json['id'] ?? json['userId']),
      userName: asString(json['userName']),
      fullName: asString(
        json['fullName'],
        asString(json['userName'], 'User'),
      ),
      avatarUrl: json['avatarUrl']?.toString(),
      isCurrentUser: isCurrentUser,
      friendshipStatus: normalizeFriendshipStatus(
        json['friendshipStatus'],
        isCurrentUser: isCurrentUser,
      ),
    );
  }
}

class SocialUserSummary {
  const SocialUserSummary({
    required this.id,
    required this.userName,
    required this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String userName;
  final String fullName;
  final String? avatarUrl;

  factory SocialUserSummary.fromJson(JsonMap json) => SocialUserSummary(
        id: asString(json['id'] ?? json['userId']),
        userName: asString(json['userName'], 'user'),
        fullName: asString(
          json['fullName'],
          asString(json['userName'], 'User'),
        ),
        avatarUrl: json['avatarUrl']?.toString(),
      );
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.otherUser,
    this.createdDate,
    this.respondedAtUtc,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final SocialUserSummary otherUser;
  final String? createdDate;
  final String? respondedAtUtc;

  bool get isPending => status.toLowerCase() == 'pending';

  factory FriendRequestItem.fromJson(JsonMap json) => FriendRequestItem(
        id: asString(json['id']),
        requesterId: asString(json['requesterId']),
        addresseeId: asString(json['addresseeId']),
        status: asString(json['status'], 'Pending'),
        otherUser: SocialUserSummary.fromJson(asMap(json['otherUser'])),
        createdDate: json['createdDate']?.toString(),
        respondedAtUtc: json['respondedAtUtc']?.toString(),
      );
}

class FriendItem {
  const FriendItem({
    required this.userId,
    required this.userName,
    required this.fullName,
    this.avatarUrl,
    this.friendsSinceUtc,
  });

  final String userId;
  final String userName;
  final String fullName;
  final String? avatarUrl;
  final String? friendsSinceUtc;

  factory FriendItem.fromJson(JsonMap json) => FriendItem(
        userId: asString(json['userId'] ?? json['id']),
        userName: asString(json['userName'], 'friend'),
        fullName: asString(
          json['fullName'],
          asString(json['userName'], 'Friend'),
        ),
        avatarUrl: json['avatarUrl']?.toString(),
        friendsSinceUtc: json['friendsSinceUtc']?.toString(),
      );
}
