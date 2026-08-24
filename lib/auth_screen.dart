import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      if (googleUser == null) {
        // The user canceled the sign-in
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      await FirebaseAuth.instance.signInWithCredential(credential);

      // No need to set isLoading to false here, as the StreamBuilder in main.dart
      // will rebuild and navigate to HomeScreen.
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الدخول: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("BARQ", style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 32)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFFF6B00), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 24)
                  ),
                  const SizedBox(width: 8),
                  const Text("برق", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 32)),
                ],
              ),
              const SizedBox(height: 16),
              const Text("أسرع توصيل في مدينتك", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 60),
              
              // Google Sign-In Button
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFFF6B00))
                  : ElevatedButton.icon(
                      onPressed: _signInWithGoogle,
                      // تم استبدال صورة SVG التي تسبب الخطأ بصورة PNG
                      icon: Image.network('https://developers.google.com/identity/images/g-logo.png', height: 24),
                      label: const Text("تسجيل الدخول باستخدام جوجل", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)), elevation: 1),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}