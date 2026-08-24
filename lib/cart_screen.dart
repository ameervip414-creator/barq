import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // <-- جديد

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isPlacingOrder = false;

  // State variables for dynamic delivery fee
  double? _deliveryFee;
  bool _isCalculatingFee = false;
  String? _feeCalculationError;

  // State variables for discount code
  final _discountCodeController = TextEditingController();
  double? _appliedDiscount;
  String? _appliedDiscountCode;
  bool _isApplyingCode = false;
  String? _discountError;

  // متغيرات جديدة لعنوان التوصيل
  final _addressController = TextEditingController();
  final _driverNoteController = TextEditingController();
  final _addressFormKey = GlobalKey<FormState>();

  // متغير جديد لتحديد طريقة الاستلام
  String _deliveryMethod = 'delivery'; // 'delivery' or 'pickup'

  // Getter لحساب الإجمالي النهائي لتجنب تكرار الكود
  double _getFinalTotal(CartProvider cart) {
    final subtotal = cart.totalAmount;
    final delivery = _deliveryMethod == 'pickup' ? 0.0 : (_deliveryFee ?? 0.0);
    final discount = _appliedDiscount ?? 0.0;
    final total = (subtotal + delivery - discount).clamp(0.0, double.infinity);
    return total;
  }

  // <-- جديد: فانكشن طلب الموقع وتعبئة العنوان
  Future<void> _getCurrentLocationAndSetAddress() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى تفعيل خدمات الموقع'),
          backgroundColor: Colors.red));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الاذن مرفوض. فعله من الاعدادات'),
          backgroundColor: Colors.red));
      return;
    }

    try {
      setState(() => _isCalculatingFee = true);
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];

      setState(() {
        _addressController.text =
            "${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}";
      });

      _calculateDeliveryFee(); // اعيد حساب الرسوم بعد ما اخدت الموقع
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في جلب الموقع: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isCalculatingFee = false);
    }
  }

  Future<void> _placeOrder(BuildContext context, CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    // التحقق من صحة عنوان التوصيل فقط إذا كان التوصيل مطلوباً
    if (_deliveryMethod == 'delivery' &&
        !_addressFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يرجى إدخال عنوان توصيل صحيح.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // التحقق من رسوم التوصيل فقط إذا كان التوصيل مطلوباً
    if (_deliveryMethod == 'delivery' &&
        (_deliveryFee == null || _feeCalculationError != null)) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('لا يمكن إتمام الطلب. يرجى التحقق من رسوم التوصيل.'),
            backgroundColor: Colors.red),
      );
      if (_feeCalculationError != null) {
        _calculateDeliveryFee();
      }
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final orderPayload = await _createOrderPayload(user, cart);
      await FirebaseFirestore.instance.collection('orders').add(orderPayload);

      cart.clearCart();

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال طلبك للمطعم بنجاح!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  Future<Map<String, dynamic>> _createOrderPayload(
      User user, CartProvider cart) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data();

    final String customerName =
        userData?['displayName'] ?? user.displayName ?? 'عميل';
    final String customerPhone = userData?['phoneNumber'] ?? 'غير متوفر';
    final String customerAddress = _deliveryMethod == 'pickup'
        ? 'استلام من المطعم'
        : _addressController.text.trim();

    final List<Map<String, dynamic>> orderItems =
        cart.items.values.map((cartItem) {
      return {
        'itemId': cartItem.item.id,
        'name': cartItem.item.name,
        'price': cartItem.item.price,
        'quantity': cartItem.quantity,
        'subtotal': cartItem.item.price * cartItem.quantity,
      };
    }).toList();

    final double deliveryFee =
        _deliveryMethod == 'pickup' ? 0.0 : (_deliveryFee ?? 0.0);

    return {
      'userId': user.uid,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'driverNote': _driverNoteController.text.trim(),
      'customerPhone': customerPhone,
      'deliveryMethod': _deliveryMethod,
      'restaurantId': cart.restaurantId,
      'restaurantName': cart.restaurantName,
      'items': orderItems,
      'deliveryFee': deliveryFee,
      'discountCode': _appliedDiscountCode,
      'discountAmount': _appliedDiscount,
      'totalAmount': _getFinalTotal(cart),
      'status': 'new',
      'timestamp': FieldValue.serverTimestamp(),
      'restaurantLat': cart.restaurantLat,
      'restaurantLng': cart.restaurantLng,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isNotEmpty) {
        if (_deliveryMethod == 'delivery') {
          _calculateDeliveryFee();
        }
      }
      _fetchUserAddress();
    });
  }

  Future<void> _fetchUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('address')) {
        final savedAddress = userDoc.data()!['address'] as String;
        if (mounted) _addressController.text = savedAddress;
      }
    } catch (e) {
      debugPrint("Error fetching user address: $e");
    }
  }

  @override
  void dispose() {
    _discountCodeController.dispose();
    _addressController.dispose();
    _driverNoteController.dispose();
    super.dispose();
  }

  Future<void> _calculateDeliveryFee() async {
    if (_deliveryMethod == 'pickup') {
      setState(() {
        _deliveryFee = 0.0;
        _isCalculatingFee = false;
        _feeCalculationError = null;
      });
      return;
    }

    setState(() {
      _isCalculatingFee = true;
      _feeCalculationError = null;
      _deliveryFee = null;
    });

    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.restaurantLat == null || cart.restaurantLng == null) {
      setState(() {
        _feeCalculationError = 'خطأ: لم يتم تحديد موقع المطعم.';
        _isCalculatingFee = false;
      });
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'يرجى تفعيل خدمات الموقع.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'يرجى السماح بالوصول للموقع لحساب رسوم التوصيل.';
      }

      Position userPosition = await Geolocator.getCurrentPosition();

      final double distanceInMeters = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        cart.restaurantLat!,
        cart.restaurantLng!,
      );

      const double maxDistanceInMeters = 10000; // 10 km
      if (distanceInMeters > maxDistanceInMeters) {
        throw 'أنت بعيد جداً عن المطعم (أكثر من 10 كم).';
      }

      double calculatedFee = 5.0;
      double distanceInKm = distanceInMeters / 1000;
      if (distanceInKm > 2) {
        calculatedFee += (distanceInKm - 2);
      }
      calculatedFee = calculatedFee.clamp(5.0, 15.0);

      if (mounted) setState(() => _deliveryFee = calculatedFee);
    } catch (e) {
      if (mounted) setState(() => _feeCalculationError = e.toString());
    } finally {
      if (mounted) setState(() => _isCalculatingFee = false);
    }
  }

  Future<void> _applyDiscountCode() async {
    final code = _discountCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final cart = Provider.of<CartProvider>(context, listen: false);

    setState(() {
      _isApplyingCode = true;
      _discountError = null;
    });

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('discount_codes')
          .doc(code)
          .get();

      if (!docSnapshot.exists) {
        throw 'كود الخصم غير صالح أو منتهي الصلاحية.';
      }

      final data = docSnapshot.data()!;
      final bool isActive = data['isActive'] ?? false;
      final Timestamp? expiryDate = data['expiryDate'];

      if (!isActive ||
          (expiryDate != null &&
              expiryDate.toDate().isBefore(DateTime.now()))) {
        throw 'كود الخصم غير صالح أو منتهي الصلاحية.';
      }

      final double discountValue = (data['value'] as num).toDouble();
      final double minOrderValue =
          (data['minOrderValue'] as num?)?.toDouble() ?? 0.0;
      final subtotal = cart.totalAmount;

      if (subtotal < minOrderValue) {
        throw 'يجب أن يكون مجموع الطلبات ${minOrderValue.toStringAsFixed(2)} ₪ على الأقل لتطبيق هذا الخصم.';
      }

      if (subtotal < discountValue) {
        throw 'مجموع الطلبات أقل من قيمة الخصم!';
      }

      setState(() {
        _appliedDiscount = discountValue;
        _appliedDiscountCode = code;
        _discountError = null;
      });
    } catch (e) {
      setState(() {
        _discountError = e.toString();
      });
    } finally {
      setState(() {
        _isApplyingCode = false;
      });
    }
  }

  void _removeDiscount() {
    setState(() {
      _appliedDiscount = null;
      _appliedDiscountCode = null;
      _discountError = null;
      _discountCodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final bool isButtonDisabled = _isPlacingOrder ||
        (_deliveryMethod == 'delivery' &&
            (_isCalculatingFee || _feeCalculationError != null));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('سلة المشتريات',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تفريغ السلة'),
                    content: const Text('هل تريد حذف جميع العناصر من السلة؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء')),
                      TextButton(
                        onPressed: () {
                          cart.clearCart();
                          Navigator.pop(ctx);
                        },
                        child: const Text('تفريغ',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('تفريغ', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? _buildEmptyCart()
          : _buildCartContent(cart, isButtonDisabled),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80, color: Colors.grey.withAlpha(102)),
          const SizedBox(height: 16),
          const Text('السلة فارغة!',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('أضف وجبات من أي مطعم',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCartContent(CartProvider cart, bool isButtonDisabled) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.restaurant,
                    color: Color(0xFFFF6B00), size: 20),
                const SizedBox(width: 8),
                Text(
                  cart.restaurantName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildCartItemsList(cart),
          _buildOrderSummary(cart, isButtonDisabled),
        ],
      ),
    );
  }

  Widget _buildCartItemsList(CartProvider cart) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: cart.items.length,
      itemBuilder: (ctx, i) {
        final cartItem = cart.items.values.toList()[i];
        final itemId = cart.items.keys.toList()[i];

        return Dismissible(
          key: Key(itemId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
          onDismissed: (_) => cart.decrementItem(itemId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartItem.item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cartItem.item.price.toStringAsFixed(2)} ₪',
                        style: const TextStyle(
                            color: Color(0xFFFF6B00), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _buildQuantityControls(cart, itemId, cartItem),
                const SizedBox(width: 12),
                Text(
                  '${(cartItem.item.price * cartItem.quantity).toStringAsFixed(2)} ₪',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(CartProvider cart, bool isButtonDisabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _addressFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeliveryMethodSelector(),
              const SizedBox(height: 16),
              if (_deliveryMethod == 'delivery') ...[
                _buildAddressInput(), // <-- هون صار فيه زر الموقع
                const SizedBox(height: 16),
                _buildDriverNoteInput(),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مجموع الطلبات',
                      style: TextStyle(color: Colors.grey)),
                  Text('${cart.totalAmount.toStringAsFixed(2)} ₪'),
                ],
              ),
              const SizedBox(height: 8),
              if (_deliveryMethod == 'delivery') _buildDeliveryFeeRow(),
              if (_appliedDiscount == null)
                _buildDiscountInputRow()
              else
                _buildDiscountDisplayRow(),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    _isCalculatingFee
                        ? 'جاري الحساب...'
                        : '${_getFinalTotal(cart).toStringAsFixed(2)} ₪',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B00),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonDisabled
                      ? null
                      : () => _placeOrder(context, cart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'إتمام الطلب',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Row _buildQuantityControls(
      CartProvider cart, String itemId, CartItem cartItem) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => cart.decrementItem(itemId),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cartItem.quantity == 1
                  ? Colors.red.shade50
                  : const Color(0xFFFFF0E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              cartItem.quantity == 1 ? Icons.delete_outline : Icons.remove,
              size: 18,
              color:
                  cartItem.quantity == 1 ? Colors.red : const Color(0xFFFF6B00),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${cartItem.quantity}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        GestureDetector(
          onTap: () => cart.incrementItem(itemId),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryMethodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'delivery',
          label: Text('توصيل'),
          icon: Icon(Icons.delivery_dining),
        ),
        ButtonSegment<String>(
          value: 'pickup',
          label: Text('استلام'),
          icon: Icon(Icons.storefront),
        ),
      ],
      selected: {_deliveryMethod},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _deliveryMethod = newSelection.first;
          _calculateDeliveryFee();
        });
      },
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: const Color(0xFFFF6B00),
        selectedForegroundColor: Colors.white,
      ),
    );
  }

  // <-- معدل: ضفنا زر الموقع
  Widget _buildAddressInput() {
    return TextFormField(
      controller: _addressController,
      decoration: InputDecoration(
        labelText: 'عنوان التوصيل',
        hintText: 'مثال: رام الله، شارع الإرسال، عمارة النجمة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon:
            const Icon(Icons.location_on_outlined, color: Color(0xFFFF6B00)),
        suffixIcon: IconButton(
          // <-- زر الموقع الحالي
          icon: const Icon(Icons.my_location, color: Color(0xFFFF6B00)),
          onPressed: _getCurrentLocationAndSetAddress,
          tooltip: 'تحديد موقعي الحالي',
        ),
      ),
      maxLines: 2,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'الرجاء إدخال عنوان التوصيل لإتمام الطلب';
        }
        if (value.trim().length < 10) {
          return 'الرجاء إدخال عنوان توصيل مفصل';
        }
        return null;
      },
    );
  }

  Widget _buildDriverNoteInput() {
    return TextField(
      controller: _driverNoteController,
      maxLines: 2,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: 'ملاحظة للسائق (اختياري)',
        hintText: 'مثال: اتصل بي عند الوصول أو اترك الطلب عند الباب',
        prefixIcon:
            const Icon(Icons.sticky_note_2_outlined, color: Color(0xFFFF6B00)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDeliveryFeeRow() {
    if (_isCalculatingFee) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('رسوم التوصيل', style: TextStyle(color: Colors.grey)),
            Row(
              children: const [
                Text('جاري الحساب...',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(width: 8),
                SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ],
        ),
      );
    }

    if (_feeCalculationError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            const Text('رسوم التوصيل', style: TextStyle(color: Colors.red)),
            const Spacer(),
            Expanded(
                child: Text(_feeCalculationError!,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: Colors.red, fontSize: 12))),
            IconButton(
                onPressed: _calculateDeliveryFee,
                icon: const Icon(Icons.refresh, color: Colors.red, size: 20)),
          ],
        ),
      );
    }

    if (_deliveryFee != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('رسوم التوصيل', style: TextStyle(color: Colors.grey)),
          Text('${_deliveryFee!.toStringAsFixed(2)} ₪'),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDiscountInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _discountCodeController,
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الخصم',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isApplyingCode ? null : _applyDiscountCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isApplyingCode
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('تطبيق'),
              ),
            ],
          ),
          if (_discountError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: Text(_discountError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscountDisplayRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('الخصم', style: TextStyle(color: Colors.green)),
              const SizedBox(width: 4),
              Text('(${_appliedDiscountCode ?? ''})',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              Text('-${_appliedDiscount?.toStringAsFixed(2) ?? '0.00'} ₪',
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: _removeDiscount,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ],
          )
        ],
      ),
    );
  }
}
