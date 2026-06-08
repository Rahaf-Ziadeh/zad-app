class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final String? photoUrl;
  final String? nationalId;
  final String status;
  final bool isApproved;
  final bool isSuspended; // رقم الهوية الوطنية — للمساءلة القانونية

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.address,
    required this.status,
    required this.isApproved,
    required this.isSuspended,
    this.photoUrl,
    this.nationalId,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final status = map['status'] ?? 'active';
    final isSuspended = status == 'suspended' || map['isSuspended'] == true;

    if (isSuspended) {
      throw Exception('تم تعليق هذا الحساب من قبل الإدارة');
    }
    return AppUser(
      uid: uid,
      name: map['name'] ?? map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'individual',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      photoUrl: map['photoUrl'],
      nationalId: map['nationalId'],
      status: status,
      isApproved: map['isApproved'] ?? false,
      isSuspended: isSuspended,
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
      'status': status,
      'isApproved': isApproved,
      'isSuspended': isSuspended,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? address,
    String? photoUrl,
    String? nationalId,
    String? status,
    bool? isApproved,
    bool? isSuspended,
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
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}
