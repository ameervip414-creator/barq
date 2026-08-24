import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("مركز المساعدة", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("الأسئلة الشائعة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFAQItem("كيف يمكنني تتبع طلبي؟", "يمكنك تتبع طلبك من خلال الضغط على زر 'تتبع الطلب' في قائمة طلباتي."),
          _buildFAQItem("ما هي مدة التوصيل المتوقعة؟", "تختلف مدة التوصيل من مطعم لآخر، وعادة ما تكون بين 20 إلى 45 دقيقة."),
          _buildFAQItem("كيف يمكنني إلغاء الطلب؟", "يمكنك التواصل مع الدعم الفني لإلغاء الطلب إذا لم يتم البدء في تحضيره."),
          const SizedBox(height: 30),
          const Text("تواصل معنا", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.phone, color: Color(0xFFFF6B00)),
            title: const Text("اتصل بنا"),
            subtitle: const Text("+962 7 0000 0000"),
            onTap: () => _launchURL(context, 'tel:+962700000000'),
          ),
          ListTile(
            leading: const Icon(Icons.email, color: Color(0xFFFF6B00)),
            title: const Text("البريد الإلكتروني"),
            subtitle: const Text("support@barq.delivery"),
            onTap: () => _launchURL(context, 'mailto:support@barq.delivery?subject=Support Request from Barq App'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(answer, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // إذا فشل فتح الرابط، قم بنسخ المعلومة إلى الحافظة
      final String copyData = url.startsWith('tel:')
          ? uri.path
          : url.startsWith('mailto:')
              ? uri.path
              : url;

      await Clipboard.setData(ClipboardData(text: copyData));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن فتح التطبيق. تم نسخ "$copyData" إلى الحافظة.')),
        );
      }
    }
  }
}
