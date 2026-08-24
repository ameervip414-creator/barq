import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String id;
  final String title; // مثل: المنزل، العمل
  final String street;
  final String building;
  final String phone;

  AddressModel({
    required this.id,
    required this.title,
    required this.street,
    required this.building,
    required this.phone,
  });

  factory AddressModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AddressModel(
      id: doc.id,
      title: data['title'] ?? '',
      street: data['street'] ?? '',
      building: data['building'] ?? '',
      phone: data['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'street': street,
      'building': building,
      'phone': phone,
    };
  }
}
