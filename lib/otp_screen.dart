import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barq/home_screen.dart';


class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("المستخدم غير مسجل دخوله");
      }

      // 1. إنشاء بيانات اعتماد باستخدام رمز التحقق
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      // 2. ربط بيانات الاعتماد الجديدة (الهاتف) بحساب المستخدم الحالي (جوجل)
      await user.linkWithCredential(credential);

      // 3. إذا نجح الربط، قم بحفظ رقم الهاتف في Firestore
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.set({
        'phoneNumber': widget.phoneNumber,
      }, SetOptions(merge: true));

      if (mounted) {
        // 4. الانتقال إلى الشاشة الرئيسية ومسح كل الشاشات السابقة
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'حدث خطأ ما.';
        if (e.code == 'invalid-verification-code') {
          errorMessage = 'رمز التحقق غير صحيح.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من رقم الهاتف'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'تم إرسال رمز التحقق إلى ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق',
                  hintText: '------',
                  counterText: "", // لإخفاء عداد الأحرف
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().length != 6) {
                    return 'الرجاء إدخال الرمز المكون من 6 أرقام';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFFF6B00))
                  : ElevatedButton(
                      onPressed: _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('تأكيد', style: TextStyle(fontSize: 18)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
