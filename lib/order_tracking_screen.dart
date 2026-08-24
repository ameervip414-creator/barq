import 'package:flutter/material.dart';

import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_model.dart';
import 'order_status_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription? _orderSubscription;
  StreamSubscription? _driverSubscription;
  StreamSubscription? _restaurantSubscription;

  OrderModel? _order;
  Map<String, dynamic>? _driverData;
  final Set<Marker> _markers = {};
  bool _isMapReady = false;
  String? _restaurantDeliveryTime;

  @override
  void initState() {
    super.initState();
    _listenToOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
    _restaurantSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToOrder() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((orderSnapshot) {
      if (!mounted || !orderSnapshot.exists) return;

      final newOrder = OrderModel.fromFirestore(orderSnapshot);

      // If the driver assignment changes, update the driver listener
      if (_order?.driverId != newOrder.driverId) {
        _listenToDriver(newOrder.driverId);
      }
      if (_order?.restaurantId != newOrder.restaurantId) {
        _listenToRestaurant(newOrder.restaurantId);
      }

      setState(() {
        _order = newOrder;
      });
      _updateRestaurantMarker();
    });
  }

  void _listenToRestaurant(String restaurantId) {
    _restaurantSubscription?.cancel();
    if (restaurantId.isEmpty) return;

    _restaurantSubscription = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      final data = snapshot.data();
      final deliveryTime = data?['deliveryTime'];
      if (deliveryTime is String && deliveryTime.trim().isNotEmpty) {
        setState(() => _restaurantDeliveryTime = deliveryTime.trim());
      }
    });
  }

  void _listenToDriver(String? driverId) {
    _driverSubscription?.cancel();
    if (driverId == null) {
      setState(() {
        _driverData = null;
        _markers.removeWhere((m) => m.markerId.value == 'driver');
      });
      return;
    }

    final driverDocRef =
        FirebaseFirestore.instance.collection('drivers').doc(driverId);
    final captainDocRef =
        FirebaseFirestore.instance.collection('captains').doc(driverId);

    _driverSubscription = driverDocRef.snapshots().listen((driverSnapshot) {
      if (!mounted) return;

      if (driverSnapshot.exists && driverSnapshot.data() != null) {
        setState(() {
          _driverData = driverSnapshot.data();
        });
        _updateDriverMarkerAndCamera();
        return;
      }

      captainDocRef.get().then((captainSnapshot) {
        if (!mounted || !captainSnapshot.exists) return;
        setState(() {
          _driverData = captainSnapshot.data();
        });
        _updateDriverMarkerAndCamera();
      });
    });
  }

  void _updateRestaurantMarker() {
    if (_order?.restaurantLat == null) return;

    final restaurantMarker = Marker(
      markerId: const MarkerId('restaurant'),
      position: LatLng(_order!.restaurantLat!, _order!.restaurantLng!),
      infoWindow: InfoWindow(title: _order!.restaurantName),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'restaurant');
      _markers.add(restaurantMarker);
    });
  }

  void _updateDriverMarkerAndCamera() {
    final data = _driverData ?? {};

    final GeoPoint? location = data['captainLocation'] is GeoPoint
        ? data['captainLocation'] as GeoPoint
        : data['driverLocation'] is GeoPoint
            ? data['driverLocation'] as GeoPoint
            : data['lastLocation'] is GeoPoint
                ? data['lastLocation'] as GeoPoint
                : data['location'] is GeoPoint
                    ? data['location'] as GeoPoint
                    : null;

    final lat = (data['currentLat'] as num?)?.toDouble() ??
        (data['latitude'] as num?)?.toDouble() ??
        (data['captainLat'] as num?)?.toDouble() ??
        location?.latitude ??
        _order?.captainLat ??
        31.9539;

    final lng = (data['currentLng'] as num?)?.toDouble() ??
        (data['longitude'] as num?)?.toDouble() ??
        (data['captainLng'] as num?)?.toDouble() ??
        location?.longitude ??
        _order?.captainLng ??
        35.9106;

    final LatLng driverPos = LatLng(lat, lng);

    final driverMarker = Marker(
      markerId: const MarkerId('driver'),
      position: driverPos,
      infoWindow: const InfoWindow(title: 'السائق'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(driverMarker);
    });

    if (_isMapReady) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(driverPos, 15));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تتبع الطلب"),
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_order == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      );
    }

    if (_order!.driverId == null) {
      return _buildNoDriverView(_order!);
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _order!.restaurantLat ?? 31.9639,
              _order!.restaurantLng ?? 35.9206,
            ),
            zoom: 14,
          ),
          markers: _markers,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _isMapReady = true;
            // If driver data is already available, update camera position
            if (_driverData != null) {
              _updateDriverMarkerAndCamera();
            }
          },
        ),
        _buildStatusPanel(context, _order!, _driverData?['name']),
      ],
    );
  }

  Widget _buildNoDriverView(OrderModel order) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF6B00)),
          const SizedBox(height: 20),
          const Text(
            "جاري البحث عن أقرب سائق...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "حالة الطلب: ${order.status}",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(
      BuildContext context, OrderModel order, String? driverName) {
    final captainName = _driverData?['fullName'] ??
        _driverData?['name'] ??
        _driverData?['captainName'] ??
        driverName ??
        order.captainName ??
        'سائق برق';

    final captainPhone = (_driverData?['phone'] ??
            _driverData?['phoneNumber'] ??
            _driverData?['captainPhone'] ??
            order.captainPhone ??
            '')
        .toString()
        .trim();
    final eta = order.estimatedDeliveryTime ??
        (order.etaMinutes == null
            ? _formatArrivalTime(order.estimatedArrivalAt) ??
                _restaurantDeliveryTime
            : '${order.etaMinutes!.round()} دقيقة');

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFF0E6),
                  child: Icon(Icons.delivery_dining, color: Color(0xFFFF6B00)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        captainName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        captainPhone,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        OrderStatusService.displayStatus(order.status),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: Color(0xFFFF6B00)),
                  tooltip: 'الاتصال بالمندوب',
                  onPressed: captainPhone.isEmpty
                      ? null
                      : () => _callCaptain(context, captainPhone),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("الوقت المتوقع للوصول"),
                Text(
                  eta ?? 'غير محدد',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B00),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callCaptain(BuildContext context, String phoneNumber) async {
    final phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الهاتف')),
      );
    }
  }

  String? _formatArrivalTime(DateTime? arrivalTime) {
    if (arrivalTime == null) return null;
    final remaining = arrivalTime.difference(DateTime.now()).inMinutes;
    return remaining <= 0 ? 'سيصل قريبًا' : '$remaining دقيقة';
  }
}
