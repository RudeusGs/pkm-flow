import '../../../core/utils/json_utils.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.userName,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.status = '',
  });

  final String id;
  final String userName;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String status;

  factory AuthUser.fromJson(JsonMap json) => AuthUser(
        id: asString(json['id']),
        userName: asString(json['userName']),
        email: asString(json['email']),
        fullName: asString(json['fullName']),
        avatarUrl: json['avatarUrl']?.toString(),
        status: asString(json['status']),
      );

  JsonMap toJson() => {
        'id': id,
        'userName': userName,
        'email': email,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'status': status,
      };
}
