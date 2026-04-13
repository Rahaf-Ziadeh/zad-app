import 'dart:async';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));

    if (email == "user@zad.com" && password == "123456") {
      return {"success": true, "role": "individual", "name": "Test User"};
    }

    if (email == "restaurant@zad.com" && password == "123456") {
      return {"success": true, "role": "restaurant", "name": "Restaurant User"};
    }

    if (email == "admin@zad.com" && password == "123456") {
      return {"success": true, "role": "admin", "name": "Admin User"};
    }

    return {"success": false, "message": "Invalid email or password"};
  }
}
