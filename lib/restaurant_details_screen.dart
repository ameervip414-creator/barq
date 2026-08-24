import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'restaurant_model.dart';
import 'menu_item_model.dart';
import 'cart_provider.dart';
import 'cart_screen.dart';
import 'widgets/restaurant_rating.dart';

class RestaurantDetailsScreen extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantDetailsScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    // هذا هو الاستعلام الصحيح لتطبيق العميل
    final Stream<QuerySnapshot> menuStream = FirebaseFirestore.instance
        .collection('menu_items')
        .where('restaurantId', isEqualTo: restaurant.id)
        .where('isAvailable',
            isEqualTo: true) // <-- الفلتر الجوهري لجلب الوجبات المتاحة فقط
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildCheckoutButton(context),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('restaurants')
                .doc(restaurant.id)
                .snapshots(),
            builder: (context, snapshot) {
              final liveRestaurant = snapshot.hasData && snapshot.data!.exists
                  ? Restaurant.fromFirestore(snapshot.data!)
                  : restaurant;
              return _buildRestaurantHeader(context, liveRestaurant);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: menuStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  if (snapshot.error.toString().contains('requires an index')) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'خطأ في قاعدة البيانات: تحتاج إلى إنشاء فهرس مركب. يرجى مراجعة رسالة الخطأ في الـ Console لإنشاء الفهرس المطلوب في Firestore.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    );
                  }
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF6B00)));
                }

                final Map<String, List<MenuItem>> categorizedItems = {};
                for (var doc in snapshot.data!.docs) {
                  final item = MenuItem.fromFirestore(doc);
                  if (!categorizedItems.containsKey(item.category)) {
                    categorizedItems[item.category] = [];
                  }
                  categorizedItems[item.category]!.add(item);
                }

                final categories = categorizedItems.keys.toList()..sort();

                if (categorizedItems.isEmpty) {
                  return const Center(
                      child: Text('لا توجد وجبات متاحة في هذا المطعم حالياً.'));
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: categories.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            category,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...categorizedItems[category]!
                            .map((item) => _buildMenuItemCard(context, item)),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return ElevatedButton.icon(
          onPressed: cart.itemCount > 0
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(
            cart.itemCount > 0
                ? 'إتمام الطلب (${cart.itemCount})'
                : 'إتمام الطلب',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantHeader(
      BuildContext context, Restaurant currentRestaurant) {
    final todayHours = _todayHours(currentRestaurant);
    final isOpen = _isRestaurantOpen(currentRestaurant, todayHours);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.network(
                currentRestaurant.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.restaurant,
                      size: 64, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              bottom: -48,
              child: Container(
                width: 104,
                height: 104,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: currentRestaurant.logoUrl != null &&
                          currentRestaurant.logoUrl!.isNotEmpty
                      ? Image.network(
                          currentRestaurant.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildLogoPlaceholder(),
                        )
                      : _buildLogoPlaceholder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 60),
        Text(
          currentRestaurant.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeaderInfo(
                icon: isOpen ? Icons.check_circle : Icons.cancel,
                label: isOpen ? 'مفتوح الآن' : 'مغلق الآن',
                color: isOpen ? Colors.green : Colors.red,
              ),
              _buildHeaderInfo(
                icon: Icons.access_time,
                label: todayHours == null
                    ? 'لا توجد أوقات'
                    : '${todayHours['opens']} - ${todayHours['closes']}',
                color: Colors.grey[700]!,
              ),
              _buildLiveRating(currentRestaurant.id),
              _buildHeaderInfo(
                icon: Icons.delivery_dining,
                label: currentRestaurant.deliveryTime,
                color: Colors.grey[700]!,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildHeaderInfo({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRating(String restaurantId) {
    return Expanded(
      child: Column(
        children: [
          const Icon(Icons.star, color: Color(0xFFFF6B00), size: 20),
          const SizedBox(height: 4),
          RestaurantRating(
            restaurantId: restaurantId,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.restaurant, size: 42, color: Colors.grey),
    );
  }

  Map<String, dynamic>? _todayHours(Restaurant currentRestaurant) {
    const dayKeys = {
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
    };
    final day = currentRestaurant.workingHours[dayKeys[DateTime.now().weekday]];
    return day is Map ? Map<String, dynamic>.from(day) : null;
  }

  bool _isRestaurantOpen(
      Restaurant currentRestaurant, Map<String, dynamic>? todayHours) {
    if (currentRestaurant.isTemporarilyClosed ||
        currentRestaurant.isEmergencyClosed) {
      return false;
    }
    if (todayHours != null && todayHours['isOpen'] != true) {
      return false;
    }
    if (currentRestaurant.isAlwaysOpen) return true;

    final opening = _timeInMinutes(
        todayHours?['opens']?.toString() ?? currentRestaurant.openingTime);
    final closing = _timeInMinutes(
        todayHours?['closes']?.toString() ?? currentRestaurant.closingTime);
    if (opening == null || closing == null) return false;

    final now = TimeOfDay.now();
    final current = now.hour * 60 + now.minute;
    if (opening == closing) return true;
    if (opening < closing) {
      return current >= opening && current < closing;
    }
    return current >= opening || current < closing;
  }

  int? _timeInMinutes(String value) {
    final normalized = value.trim().toLowerCase();
    final isPm = normalized.contains('م') || normalized.contains('pm');
    final isAm = normalized.contains('ص') || normalized.contains('am');
    final parts = normalized.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
    if (parts.length != 2) return null;
    var hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  Widget _buildMenuItemCard(BuildContext context, MenuItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child:
                              const Icon(Icons.fastfood, color: Colors.grey)),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            // التفاصيل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.price.toStringAsFixed(2)} ₪',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B00)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final result =
                              Provider.of<CartProvider>(context, listen: false)
                                  .tryAddItem(item, restaurant);

                          // Hide any previous snackbars to avoid them stacking up
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();

                          String message;
                          Color backgroundColor;

                          switch (result) {
                            case AddToCartResult.success:
                              message = 'تمت إضافة "${item.name}" إلى السلة';
                              backgroundColor = Colors.green;
                              break;
                            case AddToCartResult.differentRestaurant:
                              message =
                                  'لا يمكن إضافة وجبات من مطاعم مختلفة في نفس الطلب!';
                              backgroundColor = Colors.red;
                              break;
                            case AddToCartResult.missingLocation:
                              message =
                                  'لا يمكن الطلب من هذا المطعم حالياً (بيانات الموقع غير متوفرة).';
                              backgroundColor = Colors.orange;
                              break;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: backgroundColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
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
