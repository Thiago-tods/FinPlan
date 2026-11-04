
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
  });

  final String id;
  final String email;
  final String? name;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? json['userId']) as String,
      email: json['email'] as String,
      name: json['name'] as String?,
    );
  }
}
