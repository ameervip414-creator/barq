import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'orders_screen.dart';
import 'notifications_screen.dart';
import 'help_center_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // After logout, you should navigate to your main authentication gate or login screen
    // to prevent the user from going back to a screen that requires authentication.
    if (context.mounted) {
      // Replace this with your app's specific logic,
      // e.g., navigating to '/login' and clearing the navigation stack.
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // This is a fallback. Ideally, unauthenticated users shouldn't reach this screen.
      return Scaffold(
        appBar: AppBar(title: const Text("حسابي")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("يرجى تسجيل الدخول لعرض حسابك"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text("تسجيل الدخول"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("حسابي", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Info Card
            _buildUserInfoCard(user),
            const SizedBox(height: 24),

            // Menu Options
            _buildMenu(context),

            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("تسجيل الخروج", style: TextStyle(color: Colors.red)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFFFFF0E6),
            backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null
                ? const Icon(Icons.person, size: 35, color: Color(0xFFFF6B00))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? "مستخدم برق",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? "لا يوجد بريد إلكتروني",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildMenuItem(context, icon: Icons.shopping_bag_outlined, title: "طلباتي", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersScreen()))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(context, icon: Icons.notifications_outlined, title: "التنبيهات", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(context, icon: Icons.help_outline, title: "مركز المساعدة", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterScreen()))),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF6B00)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}