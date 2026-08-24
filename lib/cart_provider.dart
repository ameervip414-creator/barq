import 'package:flutter/foundation.dart';
import 'menu_item_model.dart';
import 'restaurant_model.dart';

enum AddToCartResult {
  success,
  differentRestaurant,
  missingLocation,
}

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  String? _restaurantId;
  String? _restaurantName;
  double? _restaurantLat;
  double? _restaurantLng;

  // Getters to access cart data
  Map<String, CartItem> get items => {..._items};
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  int get itemCount => _items.length;
  double? get restaurantLat => _restaurantLat;
  double? get restaurantLng => _restaurantLng;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.item.price * cartItem.quantity;
    });
    return total;
  }

  /// Tries to add an item to the cart.
  /// Returns `true` on success, `false` if the item is from a different restaurant.
  AddToCartResult tryAddItem(MenuItem item, Restaurant restaurant) {
    // New check: ensure the restaurant has location data before adding the first item
    if (_items.isEmpty && (restaurant.lat == null || restaurant.lng == null)) {
      return AddToCartResult.missingLocation;
    }

    // Check if cart is empty or if the item is from the same restaurant
    if (_items.isEmpty || _restaurantId == restaurant.id) {
      if (_items.isEmpty) {
        _restaurantId = restaurant.id;
        _restaurantName = restaurant.name;
        _restaurantLat = restaurant.lat;
        _restaurantLng = restaurant.lng;
      }

      if (_items.containsKey(item.id)) {
        // increase quantity
        _items.update(
          item.id,
          (existingCartItem) => CartItem(
            item: existingCartItem.item,
            quantity: existingCartItem.quantity + 1,
          ),
        );
      } else {
        // add new item
        _items.putIfAbsent(
          item.id,
          () => CartItem(item: item),
        );
      }
      notifyListeners();
      return AddToCartResult.success; // Success
    } else {
      // Item is from a different restaurant
      return AddToCartResult.differentRestaurant; // Failure
    }
  }

  /// Increments an item's quantity (used in CartScreen).
  void incrementItem(String itemId) {
    if (_items.containsKey(itemId)) {
      _items.update(
        itemId,
        (existing) => CartItem(item: existing.item, quantity: existing.quantity + 1),
      );
      notifyListeners();
    }
  }

  /// Decrements an item's quantity or removes it (used in CartScreen).
  void decrementItem(String itemId) {
    if (!_items.containsKey(itemId)) return;

    if (_items[itemId]!.quantity > 1) {
      _items.update(
        itemId,
        (existing) => CartItem(item: existing.item, quantity: existing.quantity - 1),
      );
    } else {
      _items.remove(itemId);
    }

    if (_items.isEmpty) {
      clearCart();
    } else {
      notifyListeners();
    }
  }

  /// Clears the entire cart.
  void clearCart() {
    _items = {};
    _restaurantId = null;
    _restaurantName = null;
    _restaurantLat = null;
    _restaurantLng = null;
    notifyListeners();
  }
}
