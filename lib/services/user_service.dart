import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> getUserName(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();

    return userDoc.data()?['name'] ?? 'فرد';
  }
}
