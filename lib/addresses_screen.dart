import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_model.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("عناوين التوصيل", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: user == null
        ? const Center(child: Text("يرجى تسجيل الدخول"))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('addresses')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final addresses = snapshot.data!.docs
                  .map((doc) => AddressModel.fromFirestore(doc))
                  .toList();

              if (addresses.isEmpty) {
                return const Center(child: Text("لم تقم بإضافة أي عنوان بعد"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.location_on, color: Color(0xFFFF6B00)),
                      title: Text(address.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${address.street}, ${address.building}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteAddress(user.uid, address.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6B00),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddAddressDialog(context, user!.uid),
      ),
    );
  }

  void _deleteAddress(String uid, String addressId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  void _showAddAddressDialog(BuildContext context, String uid) {
    final titleController = TextEditingController();
    final streetController = TextEditingController();
    final buildingController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة عنوان جديد"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "اسم المكان (مثل: المنزل)")),
            TextField(controller: streetController, decoration: const InputDecoration(labelText: "الشارع")),
            TextField(controller: buildingController, decoration: const InputDecoration(labelText: "البناية / رقم الشقة")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('addresses')
                  .add({
                'title': titleController.text,
                'street': streetController.text,
                'building': buildingController.text,
              });
              Navigator.pop(context);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}
