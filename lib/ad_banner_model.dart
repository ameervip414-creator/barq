import 'package:cloud_firestore/cloud_firestore.dart';

class AdBannerModel {
  final String imageUrl;
  final String? actionType; // e.g., 'open_restaurant', 'open_url'
  final String? actionValue; // e.g., restaurantId or a URL
  final int order;
  final bool isActive;

  AdBannerModel({
    required this.imageUrl,
    this.actionType,
    this.actionValue,
    required this.order,
    required this.isActive,
  });

  factory AdBannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdBannerModel(
      imageUrl: data['imageUrl'] ?? '',
      actionType: data['actionType'] as String?,
      actionValue: data['actionValue'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] ?? false,
    );
  }
}