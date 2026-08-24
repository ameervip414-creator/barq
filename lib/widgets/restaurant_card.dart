import 'package:flutter/material.dart';
import 'package:barq/restaurant_model.dart';
import 'package:barq/restaurant_details_screen.dart';
import 'restaurant_rating.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RestaurantDetailsScreen(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المطعم
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                restaurant.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.restaurant,
                      size: 50, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المطعم
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // التقييم + وقت التوصيل + رسوم التوصيل
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFFF6B00), size: 16),
                      const SizedBox(width: 4),
                      RestaurantRating(
                        restaurantId: restaurant.id,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time,
                          color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryTime,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.delivery_dining,
                          color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryFee,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
