import '../../../core/utils/json_utils.dart';
import 'auth_user.dart';

class AuthToken {
  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final AuthUser user;

  factory AuthToken.fromJson(JsonMap json) => AuthToken(
        accessToken: asString(json['accessToken']),
        refreshToken: asString(json['refreshToken']),
        tokenType: asString(json['tokenType'], 'Bearer'),
        expiresIn: asInt(json['expiresIn']),
        user: AuthUser.fromJson(asMap(json['user'])),
      );
}
