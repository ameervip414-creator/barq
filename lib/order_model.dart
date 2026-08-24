import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_status_service.dart';

class OrderModel {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final double totalAmount;
  final String status;
  final DateTime? timestamp;
  final List<dynamic> items;
  final double? deliveryFee;
  final String? discountCode;
  final double? discountAmount;
  // حقول التتبع
  final String? driverId;
  final String? captainName;
  final String? captainPhone;
  final double? captainLat;
  final double? captainLng;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? estimatedDeliveryTime;
  final double? etaMinutes;
  final DateTime? estimatedArrivalAt;

  OrderModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.totalAmount,
    required this.status,
    this.timestamp,
    required this.items,
    this.deliveryFee,
    this.discountCode,
    this.discountAmount,
    this.driverId,
    this.captainName,
    this.captainPhone,
    this.captainLat,
    this.captainLng,
    this.restaurantLat,
    this.restaurantLng,
    this.estimatedDeliveryTime,
    this.etaMinutes,
    this.estimatedArrivalAt,
  });

  static double? _readDoubleFromMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is GeoPoint) return value.latitude;
    }
    return null;
  }

  static double? _readLongitudeFromMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is GeoPoint) return value.longitude;
    }
    return null;
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final rawDriverId =
        data['driverId'] ?? data['captain_id'] ?? data['captainId'];
    final captainLocation = data['captainLocation'] ??
        data['driverLocation'] ??
        data['lastLocation'] ??
        data['location'];

    final captainLat = _readDoubleFromMap(data, [
          'captainLat',
          'driverLat',
          'currentLat',
          'latitude',
        ]) ??
        (captainLocation is GeoPoint ? captainLocation.latitude : null) ??
        ((captainLocation is Map && captainLocation['latitude'] is num)
            ? (captainLocation['latitude'] as num).toDouble()
            : null);

    final captainLng = _readLongitudeFromMap(data, [
          'captainLng',
          'driverLng',
          'currentLng',
          'longitude',
        ]) ??
        (captainLocation is GeoPoint ? captainLocation.longitude : null) ??
        ((captainLocation is Map && captainLocation['longitude'] is num)
            ? (captainLocation['longitude'] as num).toDouble()
            : null);

    return OrderModel(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: OrderStatusService.normalizeStatus(data['status'] ?? 'new'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      items: data['items'] ?? [],
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
      discountCode: data['discountCode'] as String?,
      discountAmount: (data['discountAmount'] as num?)?.toDouble(),
      driverId: rawDriverId?.toString(),
      captainName: (data['captainName'] ??
              data['driverName'] ??
              data['fullName'] ??
              data['name'])
          ?.toString(),
      captainPhone: (data['captainPhone'] ??
              data['driverPhone'] ??
              data['phoneNumber'] ??
              data['phone'])
          ?.toString(),
      captainLat: captainLat,
      captainLng: captainLng,
      restaurantLat: (data['restaurantLat'] as num?)?.toDouble(),
      restaurantLng: (data['restaurantLng'] as num?)?.toDouble(),
      estimatedDeliveryTime: _readString(data, [
        'estimatedDeliveryTime',
        'deliveryTime',
        'eta',
      ]),
      etaMinutes: (data['etaMinutes'] as num?)?.toDouble(),
      estimatedArrivalAt: (data['estimatedArrivalAt'] as Timestamp?)?.toDate(),
    );
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return '${value.toInt()} دقيقة';
    }
    return null;
  }
}
