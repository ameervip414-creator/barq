import 'package:flutter/material.dart';

class GoogleSignInButtonWeb extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleSignInButtonWeb({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,

        icon: const Icon(
          Icons.g_mobiledata,
          color: Colors.white,
          size: 30,
        ),

        label: const Text(
          'المتابعة باستخدام جوجل',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}