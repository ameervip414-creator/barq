import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'restaurant_model.dart';
import 'search_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'ad_banner_model.dart'; // تمت الإضافة
import 'widgets/restaurant_card.dart';
import 'package:url_launcher/url_launcher.dart'; // تمت الإضافة

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String userLocation = "جاري تحديد الموقع...";
  final PageController _adPageController = PageController();
  Timer? _categoryScheduleTimer;

  List<String> supportedCities = ['جنين'];

  List<Widget> get _pages => [
        _buildHomeContent(),
        const SearchScreen(),
        const OrdersScreen(),
        const ProfileScreen(),
      ];

  bool _locationError = false;

  @override
  void initState() {
    super.initState();
    _loadSupportedCities().then((_) => _getCurrentLocation());
    _categoryScheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _adPageController.dispose(); // مهم عشان الميموري
    _categoryScheduleTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _locationError = false;
    });

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        userLocation = "خدمات الموقع معطلة";
        _locationError = true;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          userLocation = "تم رفض الإذن";
          _locationError = true;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        userLocation = "الإذن مرفوض دائماً";
        _locationError = true;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String detectedCity =
            place.locality ?? place.subAdministrativeArea ?? "";

        if (supportedCities.contains(detectedCity)) {
          setState(() {
            userLocation = detectedCity;
            _locationError = false;
          });
        } else {
          setState(() {
            userLocation = "منطقة غير مدعومة";
            _locationError = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        userLocation = "خطأ في تحديد الموقع";
        _locationError = true;
      });
    }
  }

  Future<void> _loadSupportedCities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('service_areas')
          .where('isActive', isEqualTo: true)
          .get();
      final cities = snapshot.docs
          .map((doc) => (doc.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toList();
      cities.sort();
      if (mounted && cities.isNotEmpty) {
        setState(() => supportedCities = cities);
      }
    } catch (error) {
      debugPrint('Failed to load service areas: $error');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentIndex == 0
          ? _buildAppBar(FirebaseAuth.instance.currentUser)
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    final Query query = FirebaseFirestore.instance
        .collection('restaurants')
        .where('city', isEqualTo: userLocation);

    return _locationError
        ? _buildLocationErrorView()
        : StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: Text('حدث خطأ ما في تحميل البيانات'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
              }

              final List<Restaurant> restaurantsList = snapshot.data!.docs
                  .map((doc) => Restaurant.fromFirestore(doc))
                  .toList();

              final Map<String, List<Restaurant>> categorizedRestaurants = {};
              for (var restaurant in restaurantsList) {
                if (!categorizedRestaurants.containsKey(restaurant.category)) {
                  categorizedRestaurants[restaurant.category] = [];
                }
                categorizedRestaurants[restaurant.category]!.add(restaurant);
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildLocationBar(userLocation),
                    ),
                    const SizedBox(height: 16),
                    _buildAdSliders(),
                    const SizedBox(height: 16),
                    _buildCategories(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (restaurantsList.isEmpty)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child:
                                  Text("لا توجد مطاعم متوفرة في منطقتك حالياً"),
                            ))
                          else
                            ...categorizedRestaurants.keys.map((category) {
                              return _buildCategorizedRestaurantSection(
                                  category, categorizedRestaurants[category]!);
                            }),
                          const SizedBox(height: 24),
                          _buildComingSoonSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildLocationErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(userLocation,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "نعتذر، يجب تفعيل خدمات الموقع واختيار مدينة مدعومة لتتمكن من رؤية المطاعم والطلب.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00)),
              child: const Text("محاولة تحديد الموقع مرة أخرى",
                  style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _showCityPicker,
              child: const Text("اختيار المدينة يدوياً",
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(User? user) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.notifications_outlined, color: Colors.black),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const NotificationsScreen()),
          );
        },
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("BARQ",
              style: TextStyle(
                  color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(width: 4),
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.bolt, color: Colors.white, size: 16)),
          const SizedBox(width: 4),
          const Text("برق",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: user?.photoURL != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(user!.photoURL!), radius: 18)
              : const CircleAvatar(radius: 18, child: Icon(Icons.person)),
        )
      ],
    );
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("اختر مدينتك",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("(يجب أن تكون في نفس مدينة المطعم لتتمكن من الطلب)",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: supportedCities.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(supportedCities[index],
                          textAlign: TextAlign.right),
                      trailing: const Icon(Icons.location_city,
                          color: Color(0xFFFF6B00)),
                      onTap: () {
                        setState(() {
                          userLocation = supportedCities[index];
                          _locationError = false;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationBar(String location) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _showCityPicker,
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFFFF6B00), size: 20),
                const SizedBox(width: 8),
                Text(location,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.grey),
            onPressed: () {
              setState(() {
                _currentIndex = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdSliders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advertisements')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 220,
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B00))));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildDefaultAd();
        }

        final adBanners = snapshot.data!.docs
            .map((doc) => AdBannerModel.fromFirestore(doc))
            .toList();

        return Column(
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _adPageController,
                itemCount: adBanners.length,
                itemBuilder: (context, index) {
                  final banner = adBanners[index];
                  return GestureDetector(
                    onTap: () => _handleBannerTap(context, banner),
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        return progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFF6B00)));
                      },
                      errorBuilder: (context, error, stack) {
                        return _buildDefaultAd(); // لو الصورة خربت ارجع للافتراضي
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SmoothPageIndicator(
              controller: _adPageController,
              count: adBanners.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: Color(0xFFFF6B00),
                dotHeight: 8,
                dotWidth: 8,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategories() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final categories = snapshot.data!.docs.where((document) {
          final data = document.data() as Map<String, dynamic>;
          final startAt = _categoryDate(data['startAt']);
          final endAt = _categoryDate(data['endAt']);

          return (startAt == null || !now.isBefore(startAt)) &&
              (endAt == null || now.isBefore(endAt));
        }).toList()
          ..sort((first, second) {
            final firstData = first.data() as Map<String, dynamic>;
            final secondData = second.data() as Map<String, dynamic>;
            final firstOrder = (firstData['order'] as num?)?.toInt() ?? 0;
            final secondOrder = (secondData['order'] as num?)?.toInt() ?? 0;
            return firstOrder.compareTo(secondOrder);
          });

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final data = categories[index].data() as Map<String, dynamic>;
              final name = data['name'] as String?;
              if (name == null || name.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              return ActionChip(
                label: Text(name),
                labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                side: const BorderSide(color: Color(0xFFFF6B00)),
                backgroundColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(category: name),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  DateTime? _categoryDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Widget _buildDefaultAd() {
    return SizedBox(
      height: 220,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange,
        ),
        child: Center(
            child: Text('عروض مميزة قريباً',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold))),
      ),
    );
  }

  void _handleBannerTap(BuildContext context, AdBannerModel banner) async {
    if (banner.actionType == null ||
        banner.actionValue == null ||
        banner.actionValue!.isEmpty) return;

    try {
      if (banner.actionType == 'open_url') {
        final uri = Uri.tryParse(banner.actionValue!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح الرابط')),
          );
        }
      } else if (banner.actionType == 'open_restaurant') {
        // لما تجهز صفحة المطعم فك التعليق هذا
        // Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantScreen(id: banner.actionValue!)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فتح المطعم: ${banner.actionValue}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('صار خطأ: $e')),
      );
    }
  }

  Widget _buildCategorizedRestaurantSection(
      String category, List<Restaurant> restaurants) {
    if (restaurants.isEmpty) return const SizedBox.shrink();

    final displayRestaurants = restaurants.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'مطاعم $category',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            SearchScreen(category: category)));
              },
              child: const Text("عرض الكل",
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayRestaurants.length,
          itemBuilder: (context, index) {
            final restaurant = displayRestaurants[index];
            return RestaurantCard(restaurant: restaurant);
          },
        ),
      ],
    );
  }

  Widget _buildComingSoonSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('home_content')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final isVisible = data?['showComingSoon'] as bool? ?? true;
        if (!isVisible) return const SizedBox.shrink();

        final title = _settingText(
          data?['comingSoonTitle'],
          'قريباً في برق ⚡',
        );
        final description = _settingText(
          data?['comingSoonDescription'],
          'ميزات جديدة ومطاعم أكثر قادمة قريباً!',
        );

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.bolt, color: Color(0xFFFF6B00), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _settingText(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFFF6B00),
      unselectedItemColor: Colors.grey,
      currentIndex: _currentIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: "البحث"),
        BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined), label: "طلباتي"),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: "حسابي"),
      ],
    );
  }
}
