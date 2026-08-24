import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barq/home_screen.dart';
import 'package:barq/auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // إذا كان المستخدم مسجلاً دخوله، اذهب إلى الشاشة الرئيسية
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        // وإلا، اذهب إلى شاشة تسجيل الدخول
        return const AuthScreen();
      },
    );
  }
}