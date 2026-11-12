enum UserRole {
  member('member', 'Cvičiaci'),
  trainer('trainer', 'Tréner');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(Object? value) => values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => UserRole.member,
  );
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: UserRole.fromApi(json['role']),
  );

  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'role': role.apiValue,
  };

  /// Krstné meno do pozdravu.
  String get firstName => displayName.trim().split(RegExp(r'\s+')).first;
}

/// Výsledok prihlásenia: token + používateľ.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String token;
  final AuthUser user;
}
