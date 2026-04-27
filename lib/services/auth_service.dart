import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception("User data not found in Firestore");
      }

      final data = userDoc.data()!;

      final role = data["role"] ?? "individual";
      final status = data["status"] ?? "active";
      final isApproved = data["isApproved"] ?? false;

      if (status != "active") {
        throw Exception("Your account is not active");
      }

      if ((role == "restaurant" || role == "charity") && isApproved == false) {
        throw Exception("Your account is waiting for admin approval");
      }

      return AppUser(
        name: data["fullName"] ?? "User",
        email: data["email"] ?? email,
        role: role,
        phone: data["phone"] ?? "",
        address: data["address"] ?? "Ramallah",
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String role,
    String? imageUrl,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': 'active',
        'isApproved': role == 'individual',
        'profileImageUrl': imageUrl ?? '',
        'address': 'Ramallah',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Registration failed");
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}