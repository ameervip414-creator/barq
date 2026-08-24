import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barq/home_screen.dart';
import 'package:barq/phone_number_screen.dart';
import 'package:barq/notification_service.dart';

class UserSetupGate extends StatelessWidget {
  const UserSetupGate({super.key});

  /// تتحقق هذه الدالة مما إذا كان المستخدم قد أكمل إعداد ملفه الشخصي (أدخل رقم الهاتف).
  Future<bool> _isSetupComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // هذا لا يجب أن يحدث إذا كنا في هذه الشاشة
      return false;
    }

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();

    // إذا كان ملف المستخدم موجوداً ويحتوي على رقم هاتف، فإنه يعتبر مكتملاً.
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      if (data.containsKey('phoneNumber') &&
          (data['phoneNumber'] as String).isNotEmpty) {
        await NotificationService.initializeForUser(user.uid);
        return true; // الإعداد مكتمل
      }
    }

    // إذا كان هذا هو تسجيل الدخول الأول (الملف غير موجود)،
    // فسنقوم بإنشاء ملف شخصي أساسي له بالمعلومات من Google.
    if (!userDoc.exists) {
      await userDocRef.set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return false; // الإعداد غير مكتمل
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isSetupComplete(),
      builder: (context, snapshot) {
        // أثناء انتظار التحقق، نعرض شاشة تحميل.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
          );
        }

        // في حال وجود خطأ.
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('حدث خطأ: ${snapshot.error}')),
          );
        }

        // التحقق من نتيجة الدالة
        final bool isSetupComplete = snapshot.data ?? false;

        if (isSetupComplete) {
          // إذا كان الإعداد مكتملاً، انتقل إلى الشاشة الرئيسية.
          return HomeScreen();
        } else {
          // وإلا، انتقل إلى شاشة إدخال رقم الهاتف.
          return const PhoneNumberScreen();
        }
      },
    );
  }
}
