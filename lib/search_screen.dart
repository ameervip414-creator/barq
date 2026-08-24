import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'restaurant_model.dart';
import 'widgets/restaurant_card.dart';

class SearchScreen extends StatefulWidget {
  final String? category; // لاستقبال الفئة من الصفحة الرئيسية

  const SearchScreen({super.key, this.category});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchTerm = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // بناء الاستعلام بناءً على البحث والفئة
    Query query = FirebaseFirestore.instance.collection('restaurants');

    if (widget.category != null) {
      query = query.where('category', isEqualTo: widget.category);
    }

    // ملاحظة: البحث في Firestore يتطلب فهرسة أو استخدام خدمة بحث خارجية مثل Algolia للبحث الفعال في النصوص
    // هذا المثال يبحث عن بداية الاسم وهو محدود
    if (_searchTerm.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchTerm)
          .where('name', isLessThanOrEqualTo: '$_searchTerm\uf8ff');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: widget.category == null, // التركيز التلقائي فقط إذا لم يتم تحديد فئة
            decoration: const InputDecoration(
              hintText: 'ابحث عن مطعم أو وجبة...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في تحميل البيانات'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد نتائج مطابقة لبحثك'),
            );
          }

          final restaurants = snapshot.data!.docs
              .map((doc) => Restaurant.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              return RestaurantCard(restaurant: restaurants[index]);
            },
          );
        },
      ),
    );
  }
}