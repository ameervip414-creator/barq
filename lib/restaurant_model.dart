import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id;
  final String name;
  final String city;
  final String category;
  final String imageUrl;
  final String? logoUrl;
  final String deliveryTime;
  final String deliveryFee;
  final double? rating;
  final String openingTime;
  final String closingTime;
  final bool isAlwaysOpen;
  final bool isTemporarilyClosed;
  final Map<String, dynamic> workingHours;
  final bool isEmergencyClosed;
  final double? lat;
  final double? lng;

  Restaurant({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.imageUrl,
    this.logoUrl,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.rating,
    required this.openingTime,
    required this.closingTime,
    required this.isAlwaysOpen,
    required this.isTemporarilyClosed,
    required this.workingHours,
    required this.isEmergencyClosed,
    this.lat,
    this.lng,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: _stringValue(data['name'], 'اسم غير معروف'),
      city: _stringValue(data['city'], 'مدينة غير معروفة'),
      category: _stringValue(data['category'], 'متنوع'),
      imageUrl: _stringValue(data['imageUrl'],
          'https://via.placeholder.com/400x200.png?text=No+Image'), // صورة افتراضية
      logoUrl: _nullableString(data['logoUrl']),
      deliveryTime: _stringValue(data['deliveryTime'], '25-35 د'),
      deliveryFee: _stringValue(data['deliveryFee'], '10 ₪'),
      rating: _nullableDouble(data['rating']),
      openingTime:
          _stringValue(data['openingTime'] ?? data['openTime'], '09:00'),
      closingTime:
          _stringValue(data['closingTime'] ?? data['closeTime'], '23:00'),
      isAlwaysOpen: data['isAlwaysOpen'] == true,
      isTemporarilyClosed: data['isTemporarilyClosed'] == true,
      workingHours: _workingHoursValue(data['workingHours']),
      isEmergencyClosed: data['isEmergencyClosed'] == true ||
          data['emergencyClosed'] == true ||
          data['isClosed'] == true ||
          data['closedByAdmin'] == true ||
          (data.containsKey('isOpen') && data['isOpen'] == false),
      lat: _nullableDouble(data['lat']),
      lng: _nullableDouble(data['lng']),
    );
  }

  static String _stringValue(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static String? _nullableString(dynamic value) {
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static double? _nullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static Map<String, dynamic> _workingHoursValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}
