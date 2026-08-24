import 'dart:io';
import 'package:barq/auth_screen.dart';
import 'package:barq/cart_provider.dart';
import 'package:barq/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:barq/user_setup_gate.dart';
import 'package:barq/notification_service.dart';
import 'firebase_options.dart';

/// هذه الفئة تتجاوز سلوك HTTP الافتراضي لمرحلة التطوير.
/// تخبر العميل بقبول جميع شهادات الأمان، حتى لو لم تكن موثوقة.
/// تحذير: هذا غير آمن ويجب استخدامه فقط للتطوير وتصحيح الأخطاء.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة تنسيق التاريخ للغة العربية
  await initializeDateFormatting('ar', null);
  Intl.defaultLocale = 'ar';

  // تهيئة Firebase باستخدام الخيارات المخصصة لمنصتك (الطريقة الصحيحة)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // تطبيق التجاوز فقط عندما يكون التطبيق في وضع التصحيح (Debug Mode).
  // هذا يضمن عدم وجود السلوك غير الآمن في نسخة الإنتاج (Release).
  if (kDebugMode) {
    HttpOverrides.global = MyHttpOverrides();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        // أضف أي providers أخرى هنا
      ],
      child: const YallaDeliveryApp(),
    ),
  );
}

class YallaDeliveryApp extends StatelessWidget {
  const YallaDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barq',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B00),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B00)),
        useMaterial3: true,
        // يمكنك تحديد خط عالمي للتطبيق هنا
      ),
      debugShowCheckedModeBanner: false,
      // هذه "بوابة المصادقة" تقرر أي شاشة يتم عرضها بناءً على حالة تسجيل الدخول
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnapshot) {
          // 1. أثناء انتظار الاتصال، يتم عرض مؤشر تحميل.
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          // 2. في حال وجود خطأ (مثل عدم تهيئة Firebase)، يتم عرض رسالة خطأ.
          if (userSnapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('حدث خطأ: ${userSnapshot.error}'),
              ),
            );
          }
          // 3. إذا كانت بيانات المستخدم موجودة، فهو مسجل دخوله.
          if (userSnapshot.hasData) {
            // بدلاً من الانتقال مباشرة إلى الشاشة الرئيسية،
            // نستخدم "بوابة" للتحقق مما إذا كان المستخدم قد أكمل إعداد ملفه الشخصي.
            return const UserSetupGate();
          }
          // 4. وإلا، يتم عرض شاشة تسجيل الدخول.
          return AuthScreen();
        },
      ),
      routes: {
        // تأكد من أن لديك مسار لشاشة تسجيل الدخول
        '/login': (ctx) => AuthScreen(),
        '/home': (ctx) => HomeScreen(),
      },
    );
  }
}
