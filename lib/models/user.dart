class User {
  final String name;
  final String role;

  User({required this.name, required this.role});

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      name: map["name"],
      role: map["role"],
    );
  }
}