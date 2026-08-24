import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'order_status_service.dart';

class CaptainOrderStatusController {
  final FirebaseFirestore firestore;

  CaptainOrderStatusController({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> acceptOrder(String orderId) async {
    await firestore.collection('orders').doc(orderId).update({
      'status': OrderStatusService.inRoute,
      'captainUpdatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'captain',
      'captainAcceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeDelivery(String orderId) async {
    await firestore.collection('orders').doc(orderId).update({
      'status': OrderStatusService.completed,
      'captainUpdatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'captain',
      'captainDeliveredAt': FieldValue.serverTimestamp(),
    });
  }
}

class AcceptOrderButton extends StatelessWidget {
  final String orderId;
  final CaptainOrderStatusController controller;

  const AcceptOrderButton({
    super.key,
    required this.orderId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await controller.acceptOrder(orderId);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم استلام الطلب')),
            );
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ: $error')),
            );
          }
        }
      },
      child: const Text('استلام الطلب'),
    );
  }
}

class DeliveryActionButton extends StatelessWidget {
  final String orderId;
  final CaptainOrderStatusController controller;

  const DeliveryActionButton({
    super.key,
    required this.orderId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await controller.completeDelivery(orderId);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسليم الطلب')),
            );
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ: $error')),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
      ),
      child: const Text('تم التسليم'),
    );
  }
}
