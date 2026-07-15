/// User model representing an authenticated BusAlert user.
///
/// Maps to the Firebase Auth user object. The [id] is derived from the
/// Firebase UID hashCode for internal consistency.
library;

class User {
  final int id;
  final String name;
  final String email;
  final String? token; // Managed internally by Firebase Auth

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.token,
  });

  /// Creates a [User] from a JSON map returned by the backend API.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      token: json['token'] as String?,
    );
  }

  /// Serializes the user to a JSON map (for secure storage).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
    };
  }

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}
