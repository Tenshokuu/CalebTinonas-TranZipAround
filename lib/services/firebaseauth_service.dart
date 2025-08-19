import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential ucred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return ucred.user;
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? 'Login error');
      return null;
    }
  }

  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential ucred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return ucred.user;
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? 'Signup error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
