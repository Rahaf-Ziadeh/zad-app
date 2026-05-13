class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.address,
    this.photoUrl,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['fullName'] ?? map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'individual',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      photoUrl: map['photoUrl'] ?? map['profileImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'photoUrl': photoUrl,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? address,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
