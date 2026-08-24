import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_model.dart';
import 'order_status_service.dart';
import 'order_tracking_screen.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // لغرض الاختبار: طباعة معرّف المستخدم الحالي في الـ Console
    debugPrint("Current User ID (UID): ${user?.uid}");

    if (user == null) {
      return const Center(
        child: Text("يرجى تسجيل الدخول لعرض طلباتك"),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("طلباتي",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
          }
          if (snapshot.hasError) {
            // التحقق من خطأ الفهرس وتقديم رسالة واضحة
            if (snapshot.error.toString().contains('requires an index')) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'خطأ في قاعدة البيانات: تحتاج إلى إنشاء فهرس. يرجى مراجعة رسالة الخطأ في الـ Console (طرفية التصحيح) لإنشاء الفهرس المطلوب.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              );
            }
            return Center(
                child: Text("حدث خطأ في تحميل الطلبات: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 80, color: Colors.grey.withAlpha(102)),
                  const SizedBox(height: 16),
                  const Text("لا توجد طلبات سابقة",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text("ابدأ بطلب وجبتك الأولى الآن!",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderItem(context, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.restaurantName.isEmpty
                      ? 'مطعم غير معروف'
                      : order.restaurantName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '#${order.id.substring(0, 6)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'الحالة: ${_getStatusText(order.status)}',
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الإجمالي: ${order.totalAmount.toStringAsFixed(2)} ₪',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            if (order.timestamp != null)
              Text(
                // Requires 'intl' package
                DateFormat('yyyy/MM/dd - hh:mm a', 'ar')
                    .format(order.timestamp!),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const Divider(height: 24),
            Row(
              children: [
                // زر تقييم المطعم والمندوب
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        OrderStatusService.normalizeStatus(order.status) ==
                                'completed'
                            ? () => _showRatingDialog(context, order)
                            : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B00),
                      side: const BorderSide(color: Color(0xFFFF6B00)),
                      disabledForegroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("تقييم الطلب"),
                  ),
                ),
                const SizedBox(width: 10),
                // زر تتبع الطلب
                Expanded(
                  child: ElevatedButton(
                    onPressed: (OrderStatusService.normalizeStatus(
                                    order.status) ==
                                'completed' ||
                            OrderStatusService.normalizeStatus(order.status) ==
                                'cancelled')
                        ? null // تعطيل الزر للطلبات المكتملة أو الملغاة
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    OrderTrackingScreen(orderId: order.id),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("تتبع الطلب"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(BuildContext context, OrderModel order) async {
    var restaurantRating = 0;
    var driverRating = 0;
    final commentController = TextEditingController();
    final hasDriver = (order.driverId != null && order.driverId!.isNotEmpty) ||
        (order.captainName != null && order.captainName!.isNotEmpty);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('قيّم تجربتك'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRatingRow(
                      title: 'تقييم المطعم',
                      value: restaurantRating,
                      onChanged: (value) =>
                          setDialogState(() => restaurantRating = value),
                    ),
                    if (hasDriver)
                      _buildRatingRow(
                        title: 'تقييم المندوب',
                        value: driverRating,
                        onChanged: (value) =>
                            setDialogState(() => driverRating = value),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'تعليق (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed:
                      restaurantRating == 0 || (hasDriver && driverRating == 0)
                          ? null
                          : () => Navigator.pop(dialogContext, {
                                'restaurantRating': restaurantRating,
                                'driverRating': driverRating,
                                'comment': commentController.text.trim(),
                              }),
                  child: const Text('إرسال التقييم'),
                ),
              ],
            );
          },
        );
      },
    );
    commentController.dispose();

    if (result == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final firestore = FirebaseFirestore.instance;
      final reviewReference = firestore.collection('reviews').doc(order.id);
      final restaurantReference =
          firestore.collection('restaurants').doc(order.restaurantId);

      await firestore.runTransaction((transaction) async {
        final reviewSnapshot = await transaction.get(reviewReference);
        final restaurantSnapshot = await transaction.get(restaurantReference);
        final restaurantData = restaurantSnapshot.data() ?? {};
        final oldReviewData = reviewSnapshot.data();

        final oldRating = (oldReviewData?['rating'] as num?)?.toDouble();
        final oldCount = (restaurantData['ratingCount'] as num?)?.toInt() ?? 0;
        final newRating = (result['restaurantRating'] as num).toDouble();
        final newCount = oldReviewData == null
            ? oldCount + 1
            : (oldCount > 0 ? oldCount : 1);
        final oldTotal = oldReviewData == null || oldRating == null
            ? oldCount * ((restaurantData['rating'] as num?)?.toDouble() ?? 0)
            : oldCount * ((restaurantData['rating'] as num?)?.toDouble() ?? 0) -
                oldRating;
        final newAverage = (oldTotal + newRating) / newCount;

        transaction.set(reviewReference, {
          'orderId': order.id,
          'restaurantId': order.restaurantId,
          'driverId': order.driverId,
          'userId': user?.uid,
          'userName': user?.displayName ?? 'عميل',
          'rating': newRating,
          'driverRating': result['driverRating'],
          'comment': result['comment'],
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(restaurantReference, {
          'rating': double.parse(newAverage.toStringAsFixed(2)),
          'ratingCount': newCount,
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال تقييمك بنجاح')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال التقييم: $error')),
        );
      }
    }
  }

  Widget _buildRatingRow({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Row(
            children: List.generate(5, (index) {
              final rating = index + 1;
              return IconButton(
                onPressed: () => onChanged(rating),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  rating <= value ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFF6B00),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    final normalized = OrderStatusService.normalizeStatus(status);
    switch (normalized) {
      case 'new':
        return 'جديد';
      case 'preparing':
        return 'قيد التحضير';
      case 'in_route':
        return 'في الطريق';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    final normalized = OrderStatusService.normalizeStatus(status);
    switch (normalized) {
      case 'new':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'in_route':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
