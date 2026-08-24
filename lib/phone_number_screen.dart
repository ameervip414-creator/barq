import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barq/home_screen.dart';
import 'package:barq/otp_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // تم تعديل الدالة لإرسال رمز التحقق بدلاً من الحفظ المباشر
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("المستخدم غير مسجل دخوله");
      }

      // تنسيق رقم الهاتف للشكل الدولي (E.164)
      String phoneNumber = _phoneController.text.trim();
      if (phoneNumber.startsWith('0')) {
        phoneNumber = phoneNumber.substring(1);
      }
      final String fullPhoneNumber = "+970$phoneNumber";

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        // 1. التحقق التلقائي (يعمل على أندرويد)
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() { _isLoading = true; });
          await _linkCredentialAndSavePhone(user, credential, fullPhoneNumber);
        },
        // 2. فشل التحقق
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل التحقق: ${e.message}'), backgroundColor: Colors.red),
            );
          }
        },
        // 3. تم إرسال الرمز
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: verificationId,
                phoneNumber: fullPhoneNumber,
              ),
            ));
          }
        },
        // 4. انتهاء مهلة التحقق التلقائي
        codeAutoRetrievalTimeout: (String verificationId) {
          // لا حاجة لعمل شيء هنا، المستخدم سيدخل الرمز يدوياً
        },
      );

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
    // تم نقل التحكم في حالة التحميل (_isLoading) إلى داخل دوال الاستدعاء الخاصة بـ verifyPhoneNumber
    // (verificationCompleted, verificationFailed, codeSent) لذلك لا حاجة لـ finally block هنا.
  }

  // دالة مساعدة لربط الحساب وحفظ الرقم والانتقال للشاشة الرئيسية
  // هذه الدالة ضرورية للتحقق التلقائي
  Future<void> _linkCredentialAndSavePhone(User user, AuthCredential credential, String phoneNumber) async {
    await user.linkWithCredential(credential);
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userDocRef.set({'phoneNumber': phoneNumber}, SetOptions(merge: true));

    if (mounted) {
      // الانتقال للشاشة الرئيسية بعد الربط الناجح
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال التسجيل'),
        centerTitle: true,
        automaticallyImplyLeading: false, // لإخفاء زر الرجوع
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('مرحباً بك في برق!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('نحتاج إلى رقم هاتفك لتسهيل عملية التوصيل والتواصل معك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneController,
                  // تم تعديل الحقل ليناسب إدخال الرقم المحلي (10 أرقام)
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: "059xxxxxxx", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  maxLength: 10, // تحديد طول الحقل بـ 10 أرقام
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    // هذا النمط يتحقق من أن الرقم يتكون من 10 أرقام ويبدأ بـ 059 أو 056
                    final RegExp phoneRegExp = RegExp(r'^0(59|56)\d{7}$');
                    if (!phoneRegExp.hasMatch(value.trim())) {
                      return 'الرجاء إدخال رقم هاتف فلسطيني صحيح (مثال: 059xxxxxxx)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFFFF6B00))
                    : ElevatedButton(
                        onPressed: _sendOtp,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                        child: const Text('إرسال رمز التحقق'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}