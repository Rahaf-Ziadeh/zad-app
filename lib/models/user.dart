class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final String? photoUrl;
  final String? nationalId; // رقم الهوية الوطنية — للمساءلة القانونية

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.address,
    this.photoUrl,
    this.nationalId,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'individual',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      photoUrl: map['photoUrl'],
      nationalId: map['nationalId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'photoUrl': photoUrl,
      'nationalId': nationalId,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? address,
    String? photoUrl,
    String? nationalId,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      nationalId: nationalId ?? this.nationalId,
    );
  }
}
