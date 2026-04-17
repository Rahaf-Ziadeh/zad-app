import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return {
          "success": false,
          "message": "User data not found in Firestore",
        };
      }

      final data = userDoc.data()!;
      final role = data["role"];
      final status = data["status"] ?? "active";
      final isApproved = data["isApproved"] ?? false;

      if (status != "active") {
        return {"success": false, "message": "Your account is not active"};
      }

      if ((role == "restaurant" || role == "charity") && isApproved == false) {
        return {
          "success": false,
          "message": "Your account is waiting for admin approval",
        };
      }

      return {"success": true, "role": role, "message": "Login successful"};
    } on FirebaseAuthException catch (e) {
      return {"success": false, "message": e.message ?? "Login failed"};
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>> registerUser({
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
        'isApproved': role == 'individual' ? true : false,
        'profileImageUrl': imageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {"success": true, "message": "Registered successfully"};
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return {"success": false, "message": "This email is already in use"};
      } else if (e.code == 'weak-password') {
        return {"success": false, "message": "Password is too weak"};
      } else if (e.code == 'invalid-email') {
        return {"success": false, "message": "Invalid email"};
      } else {
        return {
          "success": false,
          "message": e.message ?? "Registration failed",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
