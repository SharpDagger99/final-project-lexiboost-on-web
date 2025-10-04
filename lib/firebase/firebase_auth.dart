// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up a teacher
  Future<User?> signUpTeacher({
    required String email,
    required String password,
    required String fullName,
    required String mobileNumber,
    required String address,
  }) async {
    try {
      // 1. Create account in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. Save extra teacher info in Firestore
        await _firestore.collection("users").doc(user.uid).set({
          "email": email,
          "fullname": fullName,
          "mobileNumber": mobileNumber,
          "address": address,
          "role": "teacher",
          "verified": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print("Auth Error: ${e.message}");
      rethrow; // let UI handle
    } catch (e) {
      print("General Error: $e");
      rethrow;
    }
  }
}
