import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestaurantRating extends StatelessWidget {
  final String restaurantId;
  final TextStyle? style;

  const RestaurantRating({
    super.key,
    required this.restaurantId,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('restaurantId', isEqualTo: restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text('...', style: style);
        }

        final ratings = (snapshot.data?.docs ?? [])
            .map((document) {
              final data = document.data() as Map<String, dynamic>;
              final value = data['rating'];
              return value is num ? value.toDouble() : null;
            })
            .whereType<double>()
            .toList();

        if (ratings.isEmpty) {
          return Text('لا يوجد تقييم', style: style);
        }

        final average =
            ratings.reduce((total, rating) => total + rating) / ratings.length;
        return Text(average.toStringAsFixed(1), style: style);
      },
    );
  }
}
